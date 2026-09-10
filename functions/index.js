const {initializeApp} = require('firebase-admin/app');
const {getFirestore} = require('firebase-admin/firestore');
const {getMessaging} = require('firebase-admin/messaging');
const {onDocumentCreated} = require('firebase-functions/v2/firestore');
const {recordActivity, deliverActivity} = require('./activity');
initializeApp();
const db = getFirestore();
for (const [name, path] of Object.entries({
  community: 'communities/{ownerId}/posts/{postId}',
  profile: 'users/{ownerId}/profilePosts/{postId}'
})) {
  exports[`${name}PostLiked`] = onDocumentCreated({document: `${path}/likes/{actorId}`, retry: true}, event =>
    recordActivity(db, event.data.ref.parent.parent.path, event.params.actorId));
  exports[`${name}PostActivity`] = onDocumentCreated({document: `${path}/activity/{actorId}`, retry: true}, event =>
    deliverActivity(db, getMessaging(), event.data.ref.path));
}
