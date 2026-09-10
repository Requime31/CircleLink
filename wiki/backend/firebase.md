---
title: Firebase Backend
type: backend
status: current
updated: 2026-09-11
tags: [backend, firebase, firestore, fcm]
---

# Firebase Backend

Firebase provides authentication, Firestore data, security rules, indexes, and FCM integration.
The iOS app uses `FirebaseCore`, `FirebaseAuth`, `FirebaseFirestore`, and `FirebaseMessaging`.

## Configuration

Create `CircleLink/GoogleService-Info.plist` from the checked-in example and the Firebase Console.
The real file is ignored because it contains project configuration. Enable Email/Password and
Apple providers. Sign in with Apple also requires the Xcode capability and matching Apple
Developer configuration.

Create Firestore, then deploy the repository rules and indexes:

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

## Data boundaries

- Public profile: `users/{userId}`.
- Private account data: `users/{userId}/private/account`.
- Communities: `communities/{communityId}` with `members` and `posts` subcollections.
- Chats: `chats/{chatId}` with `messages`; private list metadata lives in user `chatRefs`.
- Post likes: deterministic `likes/{userId}` documents and server-owned activity records.

The repository includes Firebase Functions for post-like activity and FCM delivery in the
`post-activity` codebase. This supersedes the older documentation claim that the repository had no
Cloud Functions. Production deployment and billing-plan selection remain operational decisions;
they must be verified before rollout rather than inferred from legacy Spark-plan guidance.

## Local validation

```bash
firebase emulators:exec --only firestore --project demo-circlelink-likes \
  'npm --prefix functions test'
```

## Sources

- Legacy `CircleLink/App/FIREBASE_SETUP.md`, migrated and reconciled with current code.
- `firebase.json`, `firestore.rules`, and `firestore.indexes.json`.
- `functions/index.js` and `functions/activity.js`.
- [Unified post likes](post-likes.md).
