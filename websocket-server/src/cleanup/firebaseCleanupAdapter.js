'use strict';

const { ensureFirebase } = require('../firebase');

function createFirebaseCleanupAdapters(firebase = ensureFirebase()) {
  const db = firebase.firestore();
  const authClient = firebase.auth();

  return {
    firestore: {
      async listDueAccounts({ now, limit, cursor }) {
        let query = db
          .collectionGroup('private')
          .where('accountState', '==', 'deactivated')
          .where('deletionRequestedAt', '<=', new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000))
          .orderBy('deletionRequestedAt')
          .orderBy(firebase.firestore.FieldPath.documentId())
          .limit(limit);
        if (cursor) query = query.startAfter(cursor.requestedAt, cursor.path);
        const snapshot = await query.get();
        const accounts = snapshot.docs.map((doc) => ({
          id: doc.ref.parent.parent.id,
          accountState: doc.get('accountState'),
          deletionRequestedAt: doc.get('deletionRequestedAt')?.toDate?.(),
          scheduledDeletionAt: addGracePeriod(doc.get('deletionRequestedAt')?.toDate?.()),
        }));
        const last = accounts.at(-1);
        return {
          accounts,
          nextCursor: snapshot.size === limit && last
            ? {
              requestedAt: last.deletionRequestedAt,
              path: snapshot.docs.at(-1).ref.path,
            }
            : null,
        };
      },

      async getAccount(userId) {
        const user = db.collection('users').doc(userId);
        const [doc, lifecycle] = await Promise.all([
          user.get(),
          user.collection('private').doc('account').get(),
        ]);
        if (!doc.exists || !lifecycle.exists) return null;
        return {
          id: doc.id,
          accountState: doc.get('accountState'),
          scheduledDeletionAt: addGracePeriod(lifecycle.get('deletionRequestedAt')?.toDate?.()),
        };
      },

      async claimAccountIfStillDue(userId, now) {
        const ref = db.collection('users').doc(userId);
        const lifecycleRef = ref.collection('private').doc('account');
        return db.runTransaction(async (transaction) => {
          const [snapshot, lifecycle] = await Promise.all([
            transaction.get(ref),
            transaction.get(lifecycleRef),
          ]);
          const deadline = addGracePeriod(lifecycle.get('deletionRequestedAt')?.toDate?.());
          if (!snapshot.exists || snapshot.get('accountState') !== 'deactivated' ||
              !(deadline instanceof Date) || deadline > now) return false;
          transaction.set(lifecycleRef, { cleanupClaimedAt: firebase.firestore.FieldValue.serverTimestamp() }, { merge: true });
          return true;
        });
      },

      async anonymizeAuthoredContent(userId, identity) {
        const documentId = firebase.firestore.FieldPath.documentId();
        const remove = firebase.firestore.FieldValue.delete();
        await anonymizeQuery(
          db.collectionGroup('posts').where('authorId', '==', userId),
          {
            authorId: 'deleted-user',
            authorDisplayName: identity.displayName,
            authorAvatarURL: remove,
            authorAvatarBase64: remove,
            authorEmail: remove,
          },
          documentId
        );
        await anonymizeQuery(
          db.collectionGroup('messages').where('senderId', '==', userId),
          {
            senderId: 'deleted-user',
            senderDisplayName: identity.displayName,
            senderAvatarURL: remove,
            senderAvatarBase64: remove,
            senderEmail: remove,
          },
          documentId
        );
      },

      async deletePrivateAccountData(userId) {
        const user = db.collection('users').doc(userId);
        // Profile posts live below a UID-bearing path and cannot be retained anonymously.
        for (const name of ['chatRefs', 'blocked', 'profilePosts']) {
          await db.recursiveDelete(user.collection(name));
        }
      },

      async deleteConnectionsAndModeration(userId) {
        await deleteQuery(db.collection('connectionRequests').where('fromUserId', '==', userId));
        await deleteQuery(db.collection('connectionRequests').where('toUserId', '==', userId));
        await deleteQuery(db.collection('reports').where('reporterId', '==', userId));
        await deleteQuery(db.collection('reports').where('reportedUserId', '==', userId));
        await deleteCollectionGroupDocumentsById(db, firebase, 'blocked', userId);
        await deleteCommunityMemberships(db, firebase, userId);
      },

      async deleteAccountIfStillDue(userId, now) {
        const ref = db.collection('users').doc(userId);
        const lifecycleRef = ref.collection('private').doc('account');
        return db.runTransaction(async (transaction) => {
          const [snapshot, lifecycle] = await Promise.all([
            transaction.get(ref),
            transaction.get(lifecycleRef),
          ]);
          const deadline = addGracePeriod(lifecycle.get('deletionRequestedAt')?.toDate?.());
          if (!snapshot.exists || snapshot.get('accountState') !== 'deactivated' ||
              !(deadline instanceof Date) || deadline > now || !lifecycle.get('cleanupClaimedAt')) return false;
          transaction.delete(lifecycleRef);
          transaction.delete(ref);
          return true;
        });
      },
    },
    auth: {
      deleteUser: (userId) => authClient.deleteUser(userId),
      isUserNotFound: (error) => error?.code === 'auth/user-not-found',
    },
  };
}

function addGracePeriod(date) {
  return date instanceof Date ? new Date(date.getTime() + 30 * 24 * 60 * 60 * 1000) : undefined;
}

async function anonymizeQuery(query, replacement, documentId) {
  let cursor = null;
  while (true) {
    let page = query.orderBy(documentId).limit(200);
    if (cursor) page = page.startAfter(cursor);
    const snapshot = await page.get();
    if (snapshot.empty) return;
    const batch = snapshot.docs[0].ref.firestore.batch();
    for (const doc of snapshot.docs) {
      batch.set(doc.ref, replacement, { merge: true });
    }
    await batch.commit();
    cursor = snapshot.docs.at(-1);
    if (snapshot.size < 200) return;
  }
}

async function deleteCollectionGroupDocumentsById(db, firebase, group, targetId) {
  const field = firebase.firestore.FieldPath.documentId();
  let cursor = null;
  while (true) {
    let query = db.collectionGroup(group).orderBy(field).limit(200);
    if (cursor) query = query.startAfter(cursor);
    const snapshot = await query.get();
    if (snapshot.empty) return;
    const matches = snapshot.docs.filter((doc) => doc.id === targetId);
    if (matches.length > 0) {
      const batch = matches[0].ref.firestore.batch();
      for (const doc of matches) batch.delete(doc.ref);
      await batch.commit();
    }
    cursor = snapshot.docs.at(-1);
    if (snapshot.size < 200) return;
  }
}

async function deleteCommunityMemberships(db, firebase, userId) {
  const field = firebase.firestore.FieldPath.documentId();
  let cursor = null;
  while (true) {
    let query = db.collectionGroup('members').orderBy(field).limit(200);
    if (cursor) query = query.startAfter(cursor);
    const snapshot = await query.get();
    if (snapshot.empty) return;
    const matches = snapshot.docs.filter((doc) => doc.id === userId);
    for (const member of matches) {
      const community = member.ref.parent.parent;
      if (!community) continue;
      await db.runTransaction(async (transaction) => {
        const [memberSnapshot, communitySnapshot] = await Promise.all([
          transaction.get(member.ref),
          transaction.get(community),
        ]);
        if (!memberSnapshot.exists) return;
        transaction.delete(member.ref);
        if (communitySnapshot.exists) {
          const count = communitySnapshot.get('memberCount');
          transaction.update(community, {
            memberCount: Math.max(0, Number.isInteger(count) ? count - 1 : 0),
          });
        }
      });
    }
    cursor = snapshot.docs.at(-1);
    if (snapshot.size < 200) return;
  }
}

async function deleteQuery(query) {
  while (true) {
    const snapshot = await query.limit(200).get();
    if (snapshot.empty) return;
    const batch = snapshot.docs[0].ref.firestore.batch();
    for (const doc of snapshot.docs) batch.delete(doc.ref);
    await batch.commit();
    if (snapshot.size < 200) return;
  }
}

module.exports = { createFirebaseCleanupAdapters, deleteCommunityMemberships };
