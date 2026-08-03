# AGENTS.md

## Cursor Cloud specific instructions

This repo is primarily an **iOS app** (`CircleLink`, SwiftUI + UIKit) plus two Node.js
backends. Read `README.md` and `ARCHITECTURE.md` first.

### What can / cannot run in the Linux cloud VM

- The **iOS app (`CircleLink`)** requires macOS + Xcode. It **cannot be built, run, or
  unit-tested on this Linux VM.** The Swift tests in `CircleLinkTests/` (Swift Testing)
  are also Xcode-only. Do not attempt to build the `.xcodeproj` here.
- The only runnable services on this VM are the **Node.js** apps: `websocket-server/`
  (active) and `functions/` (see below).

### `websocket-server/` — the runnable backend (FCM push worker + legacy WS chat)

- Standard scripts live in `websocket-server/package.json` (`npm run dev`, `npm start`);
  env vars and deploy notes are in `websocket-server/README.md`.
- **Gotcha (running without Firebase credentials):** on boot the server calls
  `ensureFirebase()` and, unless disabled, `startPushListeners()`. The FCM push worker
  needs Firebase Admin credentials (`FIREBASE_PROJECT_ID` + a service account via
  `FIREBASE_SERVICE_ACCOUNT` or `GOOGLE_APPLICATION_CREDENTIALS`). These are **not**
  present in the cloud VM by default. To run the server locally without them, start it
  with `ENABLE_PUSH=false`, e.g. `ENABLE_PUSH=false PORT=8080 npm run dev`.
- Even with push disabled, `admin.initializeApp()` still runs but is lazy, so the
  HTTP + WebSocket layer works. The WebSocket `auth` event calls Firebase
  `verifyIdToken`, so it will report `auth_failed` without real credentials — that is
  expected on this VM, not a bug.
- Health check: `curl http://localhost:8080/` returns `CircleLink WebSocket server`.

### `functions/` — UNUSED

- Firebase Cloud Functions kept only as reference. The project runs on the Firebase
  **Spark** plan; **do not deploy** `functions/` (needs Blaze). Push is handled by
  `websocket-server/`. See `functions/README.md`.
- `npm run lint` in `functions/` is just `node --check index.js`.
- `functions/package.json` pins Node 20; the VM has Node 22, which prints a harmless
  `EBADENGINE` warning on install. `websocket-server` only requires Node >= 20.

### Firebase / Supabase credentials

- Not configured in the VM. They are required for: the full push worker, the
  `scripts/seed-communities.mjs` seeder (needs `npx firebase-tools login`), and running
  the iOS app against a real project. Without them, use `ENABLE_PUSH=false` for the
  websocket-server.

### Lint / test / build quick reference

- `websocket-server`: no lint script; `node --check src/**/*.js` for a syntax check.
  No JS test suite exists.
- `functions`: `npm run lint`.
- iOS build + Swift tests: Xcode only (not available here).
