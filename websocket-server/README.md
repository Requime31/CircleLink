# CircleLink — Push Worker (`websocket-server`)

**Current job:** send **FCM push notifications** when Firestore changes (Spark plan — no Cloud Functions / Blaze).

The folder name is historical. iOS no longer uses WebSocket for chat (removed in Phase 10). Chat realtime on iOS is **Firestore listeners** only.

---

## What this process does (Phase 9)

```
iOS writes Firestore
  → this server listens (Admin SDK onSnapshot)
  → messaging.send(FCM) to users/{uid}.fcmToken
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
4. iOS app has stored `users/{uid}.fcmToken` after notification permission.
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
