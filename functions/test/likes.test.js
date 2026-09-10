const {test, before, after, beforeEach} = require('node:test');
const assert = require('node:assert/strict');
const {readFileSync} = require('node:fs');
const {initializeTestEnvironment, assertFails, assertSucceeds} = require('@firebase/rules-unit-testing');
const {doc, getDoc, setDoc, updateDoc, deleteDoc, runTransaction, serverTimestamp, collection, getDocs, increment} = require('firebase/firestore');
const {initializeApp, deleteApp} = require('firebase-admin/app');
const {getFirestore} = require('firebase-admin/firestore');
const {recordActivity, deliverActivity, activityMessage} = require('../activity');
let env, adminApp, admin;
before(async () => {
  env = await initializeTestEnvironment({projectId: 'demo-circlelink-likes', firestore: {rules: readFileSync('../firestore.rules', 'utf8')}});
  adminApp = initializeApp({projectId: 'demo-circlelink-likes'}, 'likes-tests');
  admin = getFirestore(adminApp);
});
after(async () => { await env?.cleanup(); if (adminApp) await deleteApp(adminApp); });
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async context => {
    const db = context.firestore();
    for (const id of ['author','anna','bob']) {
      await setDoc(doc(db, `users/${id}`), {displayName: id, accountState: 'active'});
      await setDoc(doc(db, `communities/group/members/${id}`), {role: 'member'});
    }
    await setDoc(doc(db, 'communities/group'), {createdBy: 'author'});
    await setDoc(doc(db, 'users/author/private/account'), {fcmToken: 'test-token'});
    for (const path of paths) await setDoc(doc(db, path), {authorId:'author', text:'Hello', createdAt: new Date()});
  });
});
const paths = ['users/author/profilePosts/post', 'communities/group/posts/post'];
async function setLiked(db, path, user, desired) {
  for (let attempt = 0; ; attempt++) {
    try { return await commitLike(db, path, user, desired); }
    catch (error) {
      if (attempt === 3 || error.code !== 'permission-denied') throw error;
      await new Promise(resolve => setTimeout(resolve, 100 * (attempt + 1)));
    }
  }
}
async function commitLike(db, path, user, desired) {
  return runTransaction(db, async tx => {
    const parent = doc(db, path), like = doc(db, `${path}/likes/${user}`);
    const post = await tx.get(parent), current = await tx.get(like);
    if (!post.exists()) throw new Error('deleted');
    if (current.exists() === desired) return;
    const count = post.data().likeCount ?? 0;
    if (desired) tx.set(like, {createdAt:serverTimestamp()}); else tx.delete(like);
    tx.update(parent, {likeCount:increment(desired ? 1 : -1)});
  });
}
for (const path of paths) {
  test(`${path}: like/unlike, missing count migration, idempotency`, async () => {
    const db = env.authenticatedContext('anna').firestore();
    await assertSucceeds(setLiked(db,path,'anna',true));
    await assertSucceeds(setLiked(db,path,'anna',true));
    assert.equal((await getDoc(doc(db,path))).data().likeCount,1);
    await assertSucceeds(setLiked(db,path,'anna',false));
    await assertSucceeds(setLiked(db,path,'anna',false));
    assert.equal((await getDoc(doc(db,path))).data().likeCount,0);
  });
  test(`${path}: concurrent same/different users`, async () => {
    const anna = env.authenticatedContext('anna').firestore(), bob = env.authenticatedContext('bob').firestore();
    const results = await Promise.allSettled([setLiked(anna,path,'anna',true),setLiked(anna,path,'anna',true),setLiked(bob,path,'bob',true)]);
    for (const result of results) assert.equal(result.status, 'fulfilled', result.reason?.message);
    assert.equal((await getDoc(doc(anna,path))).data().likeCount,2);
  });
  test(`${path}: forged counts, identities, isolated likes and edits denied`, async () => {
    const db = env.authenticatedContext('anna').firestore();
    await assertFails(updateDoc(doc(db,path),{likeCount:99}));
    await assertFails(setDoc(doc(db,`${path}/likes/anna`),{createdAt:serverTimestamp()}));
    await assertFails(setLiked(db,path,'bob',true));
    await setLiked(db,path,'anna',true);
    await assertFails(updateDoc(doc(db,`${path}/likes/anna`),{createdAt:serverTimestamp()}));
    await assertFails(deleteDoc(doc(db,`${path}/likes/anna`)));
    const author = env.authenticatedContext('author').firestore();
    await assertFails(updateDoc(doc(author,path),{likeCount:500}));
    await assertFails(setLiked(env.unauthenticatedContext().firestore(),path,'anna',true));
  });
  test(`${path}: deleted parent hides orphan likes`, async () => {
    const db = env.authenticatedContext('anna').firestore();
    await setLiked(db,path,'anna',true);
    await admin.doc(path).delete();
    await assertFails(getDocs(collection(db,`${path}/likes`)));
    await assertFails(setLiked(db,path,'anna',false));
  });
  test(`${path}: blocked in either direction and deleted users denied`, async () => {
    const db = env.authenticatedContext('anna').firestore();
    for (const block of ['users/anna/blocked/author','users/author/blocked/anna']) {
      await admin.doc(block).set({});
      await assertFails(setLiked(db,path,'anna',true));
      await admin.doc(block).delete();
    }
    await admin.doc('users/anna').delete();
    await assertFails(setLiked(db,path,'anna',true));
    await admin.doc('users/anna').set({accountState:'active'});
    await admin.doc('users/author').update({accountState:'deactivated'});
    await assertFails(setLiked(db,path,'anna',true));
  });
  test(`${path}: notifications deduplicate event retries and unlike/re-like; self-like silent`, async () => {
    const db = env.authenticatedContext('anna').firestore();
    await setLiked(db,path,'anna',true);
    await Promise.all([recordActivity(admin,path,'anna'),recordActivity(admin,path,'anna')]);
    const sent = [], messaging = {send: async payload => sent.push(payload)};
    await Promise.all([deliverActivity(admin,messaging,`${path}/activity/anna`),deliverActivity(admin,messaging,`${path}/activity/anna`)]);
    assert.equal(sent.length,1);
    assert.equal(sent[0].data.postId,'post');
    await setLiked(db,path,'anna',false);
    await setLiked(db,path,'anna',true);
    assert.equal(await recordActivity(admin,path,'anna'),false);
    await deliverActivity(admin,messaging,`${path}/activity/anna`);
    assert.equal(sent.length,1);
    await setLiked(env.authenticatedContext('author').firestore(),path,'author',true);
    assert.equal(await recordActivity(admin,path,'author'),false);
  });
}

test('aggregation message and distinct actor receipts share a five-minute window', async () => {
  const path = paths[0], now = 600000;
  for (const actor of ['anna', 'bob']) {
    await setLiked(env.authenticatedContext(actor).firestore(),path,actor,true);
    await recordActivity(admin,path,actor,now);
  }
  assert.equal((await admin.doc(`${path}/activity/bob`).get()).get('actorCount'),2);
  assert.equal(activityMessage('Anna',5),'Anna and 4 others liked your post.');
  assert.equal(activityMessage('Anna',1),'Anna liked your post.');
});
test('navigation visibility rejects deleted and both directions of blocked accounts', async () => {
  const db = env.authenticatedContext('anna').firestore();
  const access = doc(db,'users/bob/profileAccess/anna');
  await assertSucceeds(getDoc(access));
  for (const path of ['users/anna/blocked/bob','users/bob/blocked/anna']) {
    await admin.doc(path).set({});
    await assertFails(getDoc(access));
    await admin.doc(path).delete();
  }
  await admin.doc('users/bob').delete();
  await assertFails(getDoc(access));
});
test('notification delivery rechecks unlike, deleted parent/user and blocking', async () => {
  for (const invalidate of [
    async path => admin.doc(`${path}/likes/anna`).delete(),
    async path => admin.doc(path).delete(),
    async () => admin.doc('users/anna').delete(),
    async () => admin.doc('users/author/blocked/anna').set({})
  ]) {
    const path = paths[0];
    await admin.doc(path).set({authorId:'author',text:'Hello',createdAt:new Date()});
    await admin.doc('users/anna').set({accountState:'active'});
    await admin.doc('users/author/blocked/anna').delete();
    await admin.doc(`${path}/activity/anna`).delete();
    await admin.doc(`${path}/likes/anna`).set({createdAt:new Date()});
    await recordActivity(admin,path,'anna');
    await invalidate(path);
    let sent = 0;
    await deliverActivity(admin,{send:async () => sent++},`${path}/activity/anna`);
    assert.equal(sent,0);
  }
});

test('migration dry-run, repeat execution, concurrent like, and inconsistent legacy data', async () => {
  const {initializeLikeCount} = require('../scripts/migrate-like-counts');
  for (const path of paths) {
    const ref = admin.doc(path);
    assert.equal(await initializeLikeCount(admin,ref),true);
    assert.equal((await ref.get()).get('likeCount'),undefined);
    const db = env.authenticatedContext('anna').firestore();
    await Promise.all([initializeLikeCount(admin,ref,true),setLiked(db,path,'anna',true)]);
    assert.equal((await ref.get()).get('likeCount'),1);
    assert.equal(await initializeLikeCount(admin,ref,true),false);
    await ref.update({likeCount:require('firebase-admin/firestore').FieldValue.delete()});
    await assert.rejects(initializeLikeCount(admin,ref,true),/Missing count with existing likes/);
  }
});
test('community non-member cannot like and clients cannot forge activity', async () => {
  const db = env.authenticatedContext('anna').firestore();
  await admin.doc('communities/group/members/anna').delete();
  await assertFails(setLiked(db,paths[1],'anna',true));
  for (const path of paths) {
    await assertFails(setDoc(doc(db,`${path}/activity/anna`),{type:'post_activity'}));
    await assertFails(setDoc(doc(db,`${path}/activitySummary/recent`),{actorCount:999}));
  }
});
