const {FieldPath} = require('firebase-admin/firestore');

async function initializeLikeCount(db, ref, apply = false) {
  return db.runTransaction(async tx => {
    const latest = await tx.get(ref);
    if (!latest.exists || latest.get('likeCount') !== undefined) return false;
    const likes = await tx.get(ref.collection('likes').limit(1));
    if (!likes.empty) throw new Error(`Missing count with existing likes: ${ref.path}; reconcile manually.`);
    if (apply) tx.update(ref, {likeCount: 0});
    return true;
  });
}

async function migrate(db, apply) {
  for (const group of ['posts', 'profilePosts']) {
    let cursor;
    for (;;) {
      let query = db.collectionGroup(group).orderBy(FieldPath.documentId()).limit(200);
      if (cursor) query = query.startAfter(cursor);
      const page = await query.get();
      if (page.empty) break;
      for (const doc of page.docs) {
        if (!/^(communities\/[^/]+\/posts|users\/[^/]+\/profilePosts)\/[^/]+$/.test(doc.ref.path)) continue;
        if (await initializeLikeCount(db, doc.ref, apply)) {
          console.log(apply ? 'initialized' : 'would initialize', doc.ref.path);
        }
      }
      cursor = page.docs.at(-1);
    }
  }
}
// Run with ADC against an explicitly selected project. Dry-run by default.
if (require.main === module) {
  const projectId = process.env.GCLOUD_PROJECT;
  if (!projectId) throw new Error('Set GCLOUD_PROJECT explicitly.');
  const {initializeApp} = require('firebase-admin/app');
  const {getFirestore} = require('firebase-admin/firestore');
  initializeApp({projectId});
  migrate(getFirestore(), process.argv.includes('--apply')).catch(error => {
    console.error(error); process.exitCode = 1;
  });
}
module.exports = {initializeLikeCount, migrate};
