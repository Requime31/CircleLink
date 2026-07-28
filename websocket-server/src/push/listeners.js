'use strict';

const { ensureFirebase } = require('../firebase');
const {
  directChatId,
  fcmTokenForUser,
  sendPush,
  displayNameForUser,
} = require('./fcm');

/**
 * Phase 9 push worker (Spark-compatible — no Cloud Functions).
 *
 * Listens to Firestore with Admin SDK and sends FCM when:
 * 1. New message under chats/{chatId}/messages
 * 2. New pending connectionRequests
 * 3. connectionRequests pending → accepted
 *
 * On cold start we skip the initial snapshot dump so we do not re-notify
 * historical documents. Messages written while the server was down are missed
 * until the recipient opens the app (Firestore sync) — acceptable for MVP.
 *
 * @returns {() => void} unsubscribe all listeners
 */
function startPushListeners() {
  const db = ensureFirebase().firestore();
  const unsubscribers = [];

  /** @type {Map<string, string>} requestId → last known status */
  const connectionStatusById = new Map();

  // --- 1. Messages (collection group) ---------------------------------------

  let messagesReady = false;
  const unsubMessages = db.collectionGroup('messages').onSnapshot(
    async (snapshot) => {
      if (!messagesReady) {
        messagesReady = true;
        console.log(`[push] messages listener ready (skipped ${snapshot.size} existing docs)`);
        return;
      }

      for (const change of snapshot.docChanges()) {
        if (change.type !== 'added') continue;
        try {
          await handleNewMessage(change.doc);
        } catch (error) {
          console.error('[push] handleNewMessage failed:', error.message || error);
        }
      }
    },
    (error) => {
      console.error('[push] messages listener error:', error.message || error);
    }
  );
  unsubscribers.push(unsubMessages);

  // --- 2 & 3. Connection requests -------------------------------------------

  let connectionsReady = false;
  const unsubConnections = db.collection('connectionRequests').onSnapshot(
    async (snapshot) => {
      if (!connectionsReady) {
        connectionsReady = true;
        for (const doc of snapshot.docs) {
          connectionStatusById.set(doc.id, doc.get('status') || '');
        }
        console.log(
          `[push] connectionRequests listener ready (tracked ${snapshot.size} existing docs)`
        );
        return;
      }

      for (const change of snapshot.docChanges()) {
        try {
          const doc = change.doc;
          const nextStatus = doc.get('status') || '';
          const prevStatus = connectionStatusById.get(doc.id);
          connectionStatusById.set(doc.id, nextStatus);

          if (change.type === 'added' && nextStatus === 'pending') {
            await handleConnectionCreated(doc);
          } else if (prevStatus === 'pending' && nextStatus === 'accepted') {
            await handleConnectionAccepted(doc);
          }
        } catch (error) {
          console.error('[push] connection handler failed:', error.message || error);
        }
      }
    },
    (error) => {
      console.error('[push] connectionRequests listener error:', error.message || error);
    }
  );
  unsubscribers.push(unsubConnections);

  console.log('[push] Firestore → FCM listeners started (Spark / no Cloud Functions)');

  return () => {
    for (const unsub of unsubscribers) {
      unsub();
    }
  };
}

/**
 * @param {FirebaseFirestore.QueryDocumentSnapshot} doc
 */
async function handleNewMessage(doc) {
  const message = doc.data() || {};
  const senderId = message.senderId;
  if (!senderId) return;

  const chatRef = doc.ref.parent.parent;
  if (!chatRef) return;
  const chatId = chatRef.id;

  const chatSnap = await chatRef.get();
  if (!chatSnap.exists) return;

  const participantIds = chatSnap.get('participantIds') || [];
  const recipients = participantIds.filter((id) => id && id !== senderId);
  if (recipients.length === 0) return;

  const text = typeof message.text === 'string' ? message.text.trim() : '';
  const body = text.length > 0 ? text : 'Sent an image';
  const senderName = await displayNameForUser(senderId);

  await Promise.all(
    recipients.map(async (userId) => {
      // Per-user mute lives on users/{uid}/chatRefs/{chatId}.muted (Phase 6).
      const chatRefSnap = await db
        .collection('users')
        .doc(userId)
        .collection('chatRefs')
        .doc(chatId)
        .get();
      if (chatRefSnap.exists && chatRefSnap.get('muted') === true) {
        return;
      }

      const token = await fcmTokenForUser(userId);
      if (!token) return;

      await sendPush({
        token,
        title: senderName,
        body,
        data: {
          type: 'new_message',
          chatId,
          tab: 'chats',
          targetUserId: userId,
        },
      });
    })
  );
}

/**
 * @param {FirebaseFirestore.QueryDocumentSnapshot} doc
 */
async function handleConnectionCreated(doc) {
  const data = doc.data() || {};
  const toUserId = data.toUserId;
  const fromUserId = data.fromUserId;
  if (!toUserId || !fromUserId) return;

  const token = await fcmTokenForUser(toUserId);
  if (!token) return;

  const fromName = await displayNameForUser(fromUserId);

  await sendPush({
    token,
    title: 'New connection request',
    body: `${fromName} wants to connect`,
    data: {
      type: 'connection_request',
      requestId: doc.id,
      tab: 'connect',
      targetUserId: toUserId,
    },
  });
}

/**
 * @param {FirebaseFirestore.QueryDocumentSnapshot} doc
 */
async function handleConnectionAccepted(doc) {
  const data = doc.data() || {};
  const fromUserId = data.fromUserId;
  const toUserId = data.toUserId;
  if (!fromUserId || !toUserId) return;

  const token = await fcmTokenForUser(fromUserId);
  if (!token) return;

  const acceptorName = await displayNameForUser(toUserId);
  const chatId = directChatId(fromUserId, toUserId);

  await sendPush({
    token,
    title: 'Connection accepted',
    body: `${acceptorName} accepted your request`,
    data: {
      type: 'connection_accepted',
      requestId: doc.id,
      chatId,
      tab: 'connect',
      targetUserId: fromUserId,
    },
  });
}

module.exports = { startPushListeners };
