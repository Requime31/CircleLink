---
name: deploy-rules
description: Deploy CircleLink Firebase security rules (and point to Supabase storage policies). Use when the user asks to publish/deploy Firestore, Firebase Storage, or Supabase rules.
---

# Deploy rules

**Source of truth is git**, not the Firebase/Supabase consoles. If the console differs from the repo, the repo wins — deploy from here.

## Firebase (do this)

From the repo root, project `circlelink-dfa74` (see `.firebaserc`):

```bash
firebase deploy --only firestore:rules,storage
```

- Firestore rules file: `firestore.rules`
- Firebase Storage rules file: `storage.rules` (avatars path; chat images are **not** here)

Need only Firestore:

```bash
firebase deploy --only firestore:rules
```

Details: [CircleLink/App/FIREBASE_SETUP.md](CircleLink/App/FIREBASE_SETUP.md)

## Firebase (never do this)

- Do **not** `firebase deploy --only functions` or deploy `functions/`
- Do **not** switch the project to Blaze for this app
- Spark plan. FCM is the Node worker in `websocket-server/`, not Cloud Functions

## Supabase

There is **no** Supabase CLI deploy in this repo.

Chat image policies are SQL in [CircleLink/App/SUPABASE_SETUP.md](CircleLink/App/SUPABASE_SETUP.md) → section **Storage policies**. Run that SQL in the Supabase Dashboard SQL Editor if the bucket `chat-images` is new or policies are missing.

Do not invent `supabase db push` for this project.

## Secrets

Never print or commit `.env`, `GoogleService-Info.plist`, or `SupabaseSecrets.plist`.
