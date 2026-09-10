const {FieldValue} = require('firebase-admin/firestore');

/** Permanent per-post/per-actor receipt: duplicate delivery and re-like are identical. */
async function recordActivity(db, postPath, actorId, now = Date.now()) {
  const post = db.doc(postPath);
  const receipt = post.collection('activity').doc(actorId);
  const summary = post.collection('activitySummary').doc('recent');
  const windowId = Math.floor(now / 300000);
  return db.runTransaction(async tx => {
    const [parent, existing, like, actor] = await Promise.all([
      tx.get(post), tx.get(receipt), tx.get(post.collection('likes').doc(actorId)),
      tx.get(db.doc(`users/${actorId}`))
    ]);
    if (!parent.exists || existing.exists || !like.exists || !active(actor)) return false;
    const authorId = parent.get('authorId');
    if (authorId === actorId) return false;
    const [author, forward, reverse] = await Promise.all([
      tx.get(db.doc(`users/${authorId}`)),
      tx.get(db.doc(`users/${authorId}/blocked/${actorId}`)),
      tx.get(db.doc(`users/${actorId}/blocked/${authorId}`))
    ]);
    if (!active(author) || forward.exists || reverse.exists) return false;
    const previous = await tx.get(summary);
    const actorCount = previous.get('windowId') === windowId ? previous.get('actorCount') + 1 : 1;
    tx.set(summary, {windowId, actorCount, latestActorId: actorId, updatedAt: FieldValue.serverTimestamp()});
    tx.create(receipt, {
      type: 'post_activity', actorId, targetUserId: authorId, postPath,
      aggregationKey: postPath, actorCount, windowId, createdAt: FieldValue.serverTimestamp(), status: 'pending'
    });
    return true;
  });
}
function active(doc) { return doc.exists && (doc.get('accountState') ?? 'active') === 'active'; }

/** Claim before sending: at-most-once push attempt; durable activity survives a delivery failure. */
async function deliverActivity(db, messaging, receiptPath) {
  const receipt = db.doc(receiptPath);
  const payload = await db.runTransaction(async tx => {
    const event = await tx.get(receipt);
    if (!event.exists || event.get('status') !== 'pending') return null;
    const {postPath, actorId, targetUserId} = event.data();
    const [post, like, actor, author, account, forward, reverse] = await Promise.all([
      tx.get(db.doc(postPath)), tx.get(db.doc(`${postPath}/likes/${actorId}`)),
      tx.get(db.doc(`users/${actorId}`)), tx.get(db.doc(`users/${targetUserId}`)),
      tx.get(db.doc(`users/${targetUserId}/private/account`)),
      tx.get(db.doc(`users/${targetUserId}/blocked/${actorId}`)),
      tx.get(db.doc(`users/${actorId}/blocked/${targetUserId}`))
    ]);
    if (!post.exists || !like.exists || !active(actor) || !active(author)
        || forward.exists || reverse.exists || actorId === targetUserId || !account.get('fcmToken')) {
      tx.update(receipt, {status: 'suppressed'}); return null;
    }
    tx.update(receipt, {status: 'claimed', claimedAt: FieldValue.serverTimestamp()});
    const parts = postPath.split('/');
    return {
      token: account.get('fcmToken'),
      notification: {title: 'Post activity', body: activityMessage(actor.get('displayName') || 'Someone', event.get('actorCount') || 1)},
      data: {type: 'post_activity', targetUserId, postKind: parts[0] === 'users' ? 'profile' : 'community', ownerId: parts[1], postId: parts[3], aggregationKey: postPath},
      apns: {headers: {'apns-collapse-id': require('node:crypto').createHash('sha256').update(postPath).digest('hex')}}
    };
  });
  if (!payload) return;
  try {
    await messaging.send(payload);
    await receipt.update({status: 'sent'});
  } catch (error) {
    await receipt.update({status: 'failed', failureCode: error.code || 'unknown'});
    throw error;
  }
}
function activityMessage(name, count) {
  return count > 1 ? `${name} and ${count - 1} ${count === 2 ? 'other' : 'others'} liked your post.` : `${name} liked your post.`;
}
module.exports = {recordActivity, deliverActivity, activityMessage};
