'use strict';

const { ensureFirebase } = require('../src/firebase');

const DAY_MS = 24 * 60 * 60 * 1000;

async function migratePrivateAccountData({ dryRun = true, pageSize = 200 } = {}) {
  const firebase = ensureFirebase();
  const db = firebase.firestore();
  const remove = firebase.firestore.FieldValue.delete();
  let cursor = null;
  let migrated = 0;

  while (true) {
    let query = db.collection('users')
      .orderBy(firebase.firestore.FieldPath.documentId())
      .limit(pageSize);
    if (cursor) query = query.startAfter(cursor);
    const snapshot = await query.get();
    if (snapshot.empty) break;

    const batch = db.batch();
    for (const document of snapshot.docs) {
      const data = document.data();
      const privateData = {};
      const publicCleanup = {};

      for (const field of ['fcmToken', 'fcmTokenUpdatedAt', 'deletionRequestedAt']) {
        if (data[field] !== undefined) {
          privateData[field] = data[field];
          publicCleanup[field] = remove;
        }
      }

      if (data.scheduledDeletionAt !== undefined) {
        publicCleanup.scheduledDeletionAt = remove;
        if (privateData.deletionRequestedAt === undefined) {
          const deadline = data.scheduledDeletionAt?.toDate?.();
          if (deadline instanceof Date) {
            privateData.deletionRequestedAt = new Date(deadline.getTime() - 30 * DAY_MS);
          }
        }
      }
      if (data.cleanupClaimedAt !== undefined) {
        privateData.cleanupClaimedAt = data.cleanupClaimedAt;
        publicCleanup.cleanupClaimedAt = remove;
      }
      if (data.accountState === 'deactivated' && privateData.deletionRequestedAt) {
        privateData.accountState = 'deactivated';
      }

      if (Object.keys(privateData).length === 0) continue;
      migrated += 1;
      if (!dryRun) {
        batch.set(document.ref.collection('private').doc('account'), privateData, { merge: true });
        batch.update(document.ref, publicCleanup);
      }
    }
    if (!dryRun) await batch.commit();
    cursor = snapshot.docs.at(-1);
    if (snapshot.size < pageSize) break;
  }
  return { migrated, dryRun };
}

if (require.main === module) {
  const dryRun = !process.argv.includes('--apply');
  migratePrivateAccountData({ dryRun })
    .then((summary) => console.log(JSON.stringify(summary)))
    .catch((error) => {
      console.error(error);
      process.exitCode = 1;
    });
}

module.exports = { migratePrivateAccountData };
