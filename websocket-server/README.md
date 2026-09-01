# CircleLink — Push Worker (`websocket-server`)

**Current job:** send **FCM push notifications** when Firestore changes (Spark plan — no Cloud Functions / Blaze).

The folder name is historical. iOS no longer uses WebSocket for chat (removed in Phase 10). Chat realtime on iOS is **Firestore listeners** only.

### Transport security

The active Firestore Admin/FCM calls use provider HTTPS/TLS. The legacy `ws` listener in
`src/index.js` creates a plain HTTP server and does not load certificates itself. If that
legacy endpoint is ever exposed, terminate TLS at the hosting platform/reverse proxy and
accept only `wss://`; it is not used by the current iOS client. TLS is transport protection,
not chat E2EE.

---

## What this process does (Phase 9)

```
iOS writes Firestore
  → this server listens (Admin SDK onSnapshot)
  → messaging.send(FCM) to users/{uid}/private/account.fcmToken
  → iOS shows notification / deep link
```

| Listener | When | Who gets push |
|---|---|---|
| `collectionGroup('messages')` | new message doc | other chat participants |
| `connectionRequests` | new `pending` | `toUserId` |
| `connectionRequests` | `pending` → `accepted` | `fromUserId` |

Payload `data` fields match iOS `PushDeepLink`: `type`, `chatId`, `requestId`, `tab`, `targetUserId`.

### Requirements

1. Server process **must be running** (local or hosted). If it sleeps, pushes are not sent.
2. Run **one instance** for push (or you may get duplicate notifications).
3. APNs Auth Key (`.p8`) uploaded in Firebase Console → Cloud Messaging (for real devices).
4. iOS app has stored `users/{uid}/private/account.fcmToken` after notification permission.

Before deploying the private-account rules over an existing database, preview the one-time
migration with `npm run migrate:private-account`. Apply it only after reviewing the count:
`npm run migrate:private-account -- --apply`.
5. Service account must be able to use FCM + read Firestore (default Firebase Admin key is enough).

### Disable push

```bash
ENABLE_PUSH=false
```

### Cold start

On boot, initial Firestore snapshots are **not** turned into pushes (avoids spamming old messages). Events while the server was down are skipped until the user opens the app (Firestore sync).

---

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `FIREBASE_PROJECT_ID` | Yes* | Firebase project ID (same as `GoogleService-Info.plist`) |
| `FIREBASE_SERVICE_ACCOUNT` | Yes** | Service account JSON as single-line string |
| `GOOGLE_APPLICATION_CREDENTIALS` | Alt** | Path to service account JSON file (local dev) |
| `PORT` | No | Server port (default `8080`; Railway/Render set this automatically) |
| `ENABLE_PUSH` | No | Firestore → FCM worker (default `true`; set `false` to disable) |

\* Required when not embedded in service account JSON.  
\** One of `FIREBASE_SERVICE_ACCOUNT` or `GOOGLE_APPLICATION_CREDENTIALS` is required.

Copy `.env.example` to `.env` for local development.

---

## Local Development

```bash
cd websocket-server
npm install

# Set credentials (pick one):
export FIREBASE_PROJECT_ID=your-project-id
export GOOGLE_APPLICATION_CREDENTIALS=./serviceAccountKey.json
# OR:
# export FIREBASE_SERVICE_ACCOUNT='{"type":"service_account",...}'

npm run dev
```

### Get a Firebase service account key

1. Firebase Console → Project Settings → Service Accounts
2. Generate new private key → save as `serviceAccountKey.json`
3. **Never commit this file** (listed in `.gitignore`)

---

## Deploy

Keep at least one instance awake if you rely on push (sleeping dyno = no FCM).

### Railway

1. Create a project → deploy from GitHub (root directory: `websocket-server`)
2. Env: `FIREBASE_PROJECT_ID`, `FIREBASE_SERVICE_ACCOUNT` (JSON as one line)
3. Optional: `ENABLE_PUSH=true` (default on)
4. Railway sets `PORT` automatically

### Render

1. New **Web Service** → root directory `websocket-server`
2. Build: `npm install` · Start: `npm start`
3. Env: `FIREBASE_PROJECT_ID`, `FIREBASE_SERVICE_ACCOUNT`

### Docker

```bash
docker build -t circlelink-push .
docker run -p 8080:8080 \
  -e FIREBASE_PROJECT_ID=your-project-id \
  -e FIREBASE_SERVICE_ACCOUNT='{"type":"service_account",...}' \
  circlelink-push
```

---

## Legacy: WebSocket chat (not used by iOS)

This package still contains an old **WebSocket chat** protocol from Phase 4 (rooms, `auth` / `join` / `message` events).

- **iOS does not connect to it** anymore (Phase 10 removed the client).
- Do **not** configure `WEBSOCKET_URL` in the iOS app — that path is gone.
- For junior work: ignore the WS chat code; focus on the **push worker** (`src/push/`).

Historical baseline with the old iOS WebSocket client: git branch `websocketlocal`.

---

## Scheduled account cleanup

The cleanup CLI is a separate, repeatable job. It does not use Cloud Functions and does
not alter the always-on FCM listener process.

```bash
# Safe production connectivity/schema check: performs reads and logs counts only.
npm run cleanup:accounts:dry-run

# Destructive run after reviewing the dry-run summary.
npm run cleanup:accounts
```

The host scheduler contract is: run one invocation at a time (recommended daily), provide
the same Firebase Admin environment as the push worker, set a timeout longer than the
largest expected page, and alert on a non-zero exit status. Railway Cron, Render Cron Job,
or a host cron may invoke `npm run cleanup:accounts`; this repository does not deploy or
configure the schedule.

Optional tuning: `ACCOUNT_CLEANUP_PAGE_SIZE` (default 25) and
`ACCOUNT_CLEANUP_CONCURRENCY` (default 3). Optional Supabase server cleanup uses
`SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, and `SUPABASE_STORAGE_BUCKET`. Never expose
the service-role key to the iOS app or commit it.

### Deletion and anonymization matrix

| Data | Cleanup policy |
|---|---|
| Firebase Auth user | Delete; missing user is an idempotent success |
| `users/{uid}` | Delete last, only after a transactional state/deadline recheck and cleanup claim |
| `private`, `chatRefs`, own `blocked` | Delete recursively |
| Connections, reports, memberships, references from other block lists | Delete in bounded queries |
| Community/profile posts | Preserve content and stable `authorId`; replace author snapshot with `Deleted User`, remove email/avatar snapshots |
| Chat messages | Preserve content and stable `senderId`; replace sender snapshot with `Deleted User`, remove email/avatar snapshots |
| Chat/community/profile-post media | Preserve with their content |
| `profiles/{uid}/...` Supabase prefix | Delete when server storage credentials are configured; current iOS avatars are Firestore base64 |

Structured logs contain aggregate counts only. User IDs, email addresses, tokens, storage
keys, and service credentials are never logged. A partial failure leaves the claimed due
profile as a retry marker; rerunning the command safely continues cleanup.
