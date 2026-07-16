# CircleLink WebSocket Server

Minimal Node.js WebSocket server for CircleLink MVP (Phase 4) **+ Phase 9 FCM push worker**.

## Features

- Firebase ID token verification on connect (`auth` event)
- Room routing: `chat:{chatId}`
- Events: `auth`, `join`, `leave`, `message`, `message.new`, `error`
- Broadcasts `message.new` to all participants in a chat room
- **Phase 9:** Firestore listeners → FCM (works on **Spark**, no Cloud Functions / Blaze)

## Phase 9 — Push (Firestore → FCM)

Runs inside this same Node process. No Blaze plan required.

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

1. Server process **must be running** (local or Railway). If the server is asleep, pushes are not sent.
2. Run **one instance** of this service for push (or you may get duplicate notifications).
3. APNs Auth Key (`.p8`) uploaded in Firebase Console → Cloud Messaging (for real devices).
4. iOS app has stored `users/{uid}.fcmToken` after notification permission.
5. Service account used by this server must be able to use FCM + read Firestore (default Firebase Admin key is enough).

### Disable push

```bash
ENABLE_PUSH=false
```

### Cold start

On boot, initial Firestore snapshots are **not** turned into pushes (avoids spamming old messages). Events while the server was down are skipped until the user opens the app (Firestore sync).

## Event Protocol

Matches the iOS `WebSocketEvent` model (`CircleLink/Data/Network/WebSocketEvent.swift`).

### Client → Server

```json
{ "type": "auth", "token": "<firebase-id-token>" }
{ "type": "join", "chatId": "abc123" }
{ "type": "leave", "chatId": "abc123" }
{ "type": "message", "chatId": "abc123", "text": "Hello", "clientMessageId": "uuid" }
```

### Server → Client

```json
{ "type": "message.new", "chatId": "abc123", "messageId": "uuid", "senderId": "uid", "text": "Hello", "createdAt": "2026-07-15T12:00:00.000Z" }
{ "type": "error", "code": "auth_failed" }
```

### Error codes

| Code | Meaning |
|------|---------|
| `auth_timeout` | No `auth` event within timeout |
| `auth_required` | Non-auth event before authentication |
| `auth_failed` | Invalid or expired Firebase token |
| `missing_token` | Auth event without token |
| `not_authenticated` | join/leave/message before auth |
| `invalid_json` | Malformed JSON |
| `invalid_chat_id` | Missing or invalid chatId |
| `invalid_message` | Missing or invalid text |
| `unknown_event` | Unrecognized event type |
| `already_authenticated` | Duplicate auth event |

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `FIREBASE_PROJECT_ID` | Yes* | Firebase project ID (same as `GoogleService-Info.plist`) |
| `FIREBASE_SERVICE_ACCOUNT` | Yes** | Service account JSON as single-line string |
| `GOOGLE_APPLICATION_CREDENTIALS` | Alt** | Path to service account JSON file (local dev) |
| `PORT` | No | Server port (default `8080`; Railway/Render set this automatically) |
| `AUTH_TIMEOUT_MS` | No | Auth timeout in ms (default `10000`) |
| `ENABLE_PUSH` | No | Firestore → FCM worker (default `true`; set `false` to disable) |

\* Required when not embedded in service account JSON.  
\** One of `FIREBASE_SERVICE_ACCOUNT` or `GOOGLE_APPLICATION_CREDENTIALS` is required for token verification.

Copy `.env.example` to `.env` for local development.

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

Server listens on `ws://localhost:8080`.

### Get a Firebase service account key

1. Firebase Console → Project Settings → Service Accounts
2. Generate new private key → save as `serviceAccountKey.json`
3. **Never commit this file** (listed in `.gitignore`)

## Deploy

### Railway

1. Create a new project → Deploy from GitHub repo (or CLI)
2. Set root directory to `websocket-server` (if monorepo)
3. Add environment variables:
   - `FIREBASE_PROJECT_ID`
   - `FIREBASE_SERVICE_ACCOUNT` (paste full JSON as one line)
   - (optional) `ENABLE_PUSH=true` — default on
4. Railway sets `PORT` automatically
5. Keep at least one instance awake if you rely on push (sleeping dyno = no FCM)
6. Use the generated URL with `wss://` in the iOS app (WS chat path); push worker does not need the iOS app to connect via WebSocket

### Render

1. New **Web Service** → connect repo
2. Root directory: `websocket-server`
3. Build command: `npm install`
4. Start command: `npm start`
5. Add env vars: `FIREBASE_PROJECT_ID`, `FIREBASE_SERVICE_ACCOUNT`
6. Enable WebSocket support in service settings

### Fly.io

```bash
cd websocket-server
fly launch --name circlelink-ws --no-deploy

# Set secrets
fly secrets set FIREBASE_PROJECT_ID=your-project-id
fly secrets set FIREBASE_SERVICE_ACCOUNT='{"type":"service_account",...}'

fly deploy
```

`fly.toml` example (auto-generated by `fly launch`):

```toml
app = "circlelink-ws"
primary_region = "ams"

[build]
  dockerfile = "Dockerfile"

[http_service]
  internal_port = 8080
  force_https = true
  auto_stop_machines = "stop"
  auto_start_machines = true
  min_machines_running = 0

  [[http_service.checks]]
    grace_period = "10s"
    interval = "30s"
    method = "GET"
    path = "/"
    timeout = "5s"
```

### Docker (any platform)

```bash
docker build -t circlelink-ws .
docker run -p 8080:8080 \
  -e FIREBASE_PROJECT_ID=your-project-id \
  -e FIREBASE_SERVICE_ACCOUNT='{"type":"service_account",...}' \
  circlelink-ws
```

## iOS Client Configuration

Set the WebSocket URL in Xcode build settings or `Info.plist`:

- Debug: `ws://localhost:8080` (simulator) or `ws://<your-mac-ip>:8080` (device)
- Production: `wss://your-deployed-host`

The iOS app reads `WEBSOCKET_URL` from the bundle (see `WebSocketConfiguration.swift`).

## Architecture

```
iOS WebSocketClient
  → connect + auth(token)
  → join(chatId) / leave(chatId)
  → send(message)

Node.js Server
  → verifyIdToken (firebase-admin)
  → room: chat:{chatId}
  → broadcast message.new
```

Firestore remains the source of truth for message persistence (Phase 5+). WebSocket is for instant foreground delivery only.
