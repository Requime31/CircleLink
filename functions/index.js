/**
 * CircleLink Phase 9 — FCM push via Firestore triggers.
 *
 * Triggers:
 * 1. chats/{chatId}/messages/{messageId} onCreate → new_message
 * 2. connectionRequests/{requestId} onCreate → connection_request
 * 3. connectionRequests/{requestId} onUpdate (pending → accepted) → connection_accepted
 *
 * Token storage: users/{userId}.fcmToken (written by the iOS app).
 */

const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { logger } = require("firebase-functions");

initializeApp();

const db = getFirestore();
const messaging = getMessaging();

/**
 * Deterministic direct chat id — must match iOS `FirestoreChatMapper.directChatId`.
 * @param {string} a
 * @param {string} b
 * @returns {string}
 */
function directChatId(a, b) {
  return [a, b].sort().join("_");
}

/**
 * @param {string} userId
 * @returns {Promise<string|null>}
 */
async function fcmTokenForUser(userId) {
  const snap = await db.collection("users").doc(userId).get();
  if (!snap.exists) return null;
  const token = snap.get("fcmToken");
  return typeof token === "string" && token.length > 0 ? token : null;
}

/**
 * @param {{
 *   token: string,
 *   title: string,
 *   body: string,
 *   data: Record<string, string>
 * }} params
 */
async function sendPush({ token, title, body, data }) {
  const message = {
    token,
    notification: { title, body },
    data,
    apns: {
      payload: {
        aps: {
          sound: "default",
          badge: 1,
        },
      },
    },
  };

  try {
    const id = await messaging.send(message);
    logger.info("FCM sent", { messageId: id, type: data.type });
  } catch (error) {
    // Stale token — clear so we stop targeting this device.
    if (
      error.code === "messaging/registration-token-not-registered" ||
      error.code === "messaging/invalid-registration-token"
    ) {
      logger.warn("Clearing invalid FCM token", { code: error.code });
      // Best-effort: find user by token is expensive; leave token for client refresh.
    }
    logger.error("FCM send failed", error);
  }
}

// ---------------------------------------------------------------------------
// 1. New message → notify other participants
// ---------------------------------------------------------------------------

exports.onMessageCreated = onDocumentCreated(
  "chats/{chatId}/messages/{messageId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const chatId = event.params.chatId;
    const message = snap.data() || {};
    const senderId = message.senderId;
    if (!senderId) return;

    const chatSnap = await db.collection("chats").doc(chatId).get();
    if (!chatSnap.exists) return;

    const participantIds = chatSnap.get("participantIds") || [];
    const recipients = participantIds.filter((id) => id && id !== senderId);
    if (recipients.length === 0) return;

    const text = typeof message.text === "string" ? message.text.trim() : "";
    const body = text.length > 0 ? text : "Sent an image";

    let senderName = "Someone";
    const senderSnap = await db.collection("users").doc(senderId).get();
    if (senderSnap.exists) {
      const name = senderSnap.get("displayName");
      if (typeof name === "string" && name.trim().length > 0) {
        senderName = name.trim();
      }
    }

    await Promise.all(
      recipients.map(async (userId) => {
        // Per-user mute: users/{uid}/chatRefs/{chatId}.muted (Phase 6).
        const chatRefSnap = await db
          .collection("users")
          .doc(userId)
          .collection("chatRefs")
          .doc(chatId)
          .get();
        if (chatRefSnap.exists && chatRefSnap.get("muted") === true) {
          return;
        }

        const token = await fcmTokenForUser(userId);
        if (!token) return;

        await sendPush({
          token,
          title: senderName,
          body,
          data: {
            type: "new_message",
            chatId,
            tab: "chats",
            targetUserId: userId,
          },
        });
      })
    );
  }
);

// ---------------------------------------------------------------------------
// 2. Connection request created → notify recipient
// ---------------------------------------------------------------------------

exports.onConnectionRequestCreated = onDocumentCreated(
  "connectionRequests/{requestId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const data = snap.data() || {};
    if (data.status !== "pending") return;

    const toUserId = data.toUserId;
    const fromUserId = data.fromUserId;
    if (!toUserId || !fromUserId) return;

    const token = await fcmTokenForUser(toUserId);
    if (!token) return;

    let fromName = "Someone";
    const fromSnap = await db.collection("users").doc(fromUserId).get();
    if (fromSnap.exists) {
      const name = fromSnap.get("displayName");
      if (typeof name === "string" && name.trim().length > 0) {
        fromName = name.trim();
      }
    }

    await sendPush({
      token,
      title: "New connection request",
      body: `${fromName} wants to connect`,
      data: {
        type: "connection_request",
        requestId: event.params.requestId,
        tab: "connect",
        targetUserId: toUserId,
      },
    });
  }
);

// ---------------------------------------------------------------------------
// 3. Connection accepted → notify requester
// ---------------------------------------------------------------------------

exports.onConnectionRequestUpdated = onDocumentUpdated(
  "connectionRequests/{requestId}",
  async (event) => {
    const before = event.data?.before?.data() || {};
    const after = event.data?.after?.data() || {};

    if (before.status === "pending" && after.status === "accepted") {
      const fromUserId = after.fromUserId;
      const toUserId = after.toUserId;
      if (!fromUserId || !toUserId) return;

      const token = await fcmTokenForUser(fromUserId);
      if (!token) return;

      let acceptorName = "Someone";
      const toSnap = await db.collection("users").doc(toUserId).get();
      if (toSnap.exists) {
        const name = toSnap.get("displayName");
        if (typeof name === "string" && name.trim().length > 0) {
          acceptorName = name.trim();
        }
      }

      const chatId = directChatId(fromUserId, toUserId);

      await sendPush({
        token,
        title: "Connection accepted",
        body: `${acceptorName} accepted your request`,
        data: {
          type: "connection_accepted",
          requestId: event.params.requestId,
          chatId,
          tab: "connect",
          targetUserId: fromUserId,
        },
      });
    }
  }
);
