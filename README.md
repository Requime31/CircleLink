# CircleLink

iOS community messenger MVP: interest-based communities, Connect matching, and chat.

- **UI:** SwiftUI screens + UIKit chat
- **Backend:** Firebase Auth + Firestore (Spark plan)
- **Chat images:** Supabase Storage
- **Realtime chat:** Firestore listeners (not WebSocket on iOS)
- **Push:** FCM via Node worker in `websocket-server/` (Spark — no Cloud Functions / Blaze)

Minimum iOS: **16+**.

---

## Requirements

| What | Why |
|---|---|
| macOS + [Xcode](https://developer.apple.com/xcode/) (recent) | Build and run the app |
| Apple ID / signing | Simulator usually works; device needs a team |
| [SwiftLint](https://github.com/realm/SwiftLint) (optional) | Style warnings in Xcode during build — `brew install swiftlint` |
| Firebase project | Auth, Firestore, FCM — see setup below |
| Supabase project (optional for text-only) | Chat image uploads |
| Node.js (optional) | Run the push worker locally |

---

## Open in Xcode

1. Clone the repo and open the project (not a random folder):

```bash
cd CircleLink
open CircleLink.xcodeproj
```

2. Select the **CircleLink** scheme and an iOS Simulator (e.g. iPhone 16).
3. If SPM packages fail: **File → Packages → Resolve Package Versions**.

### SwiftLint

SwiftLint runs automatically on every **CircleLink** build (warnings only — it does not fail ⌘B).

```bash
brew install swiftlint   # once
swiftlint lint           # optional manual run from repo root
```

Config: [`.swiftlint.yml`](.swiftlint.yml). Lint covers `CircleLink/` and `CircleLinkTests/`.

---

## Run on Simulator

1. Add Firebase config (required):

```bash
cp CircleLink/GoogleService-Info.plist.example CircleLink/GoogleService-Info.plist
```

Fill `GoogleService-Info.plist` from [Firebase Console](https://console.firebase.google.com) (see [FIREBASE_SETUP.md](CircleLink/App/FIREBASE_SETUP.md)).

2. (Optional) Chat images — copy and fill Supabase secrets:

```bash
cp CircleLink/SupabaseSecrets.plist.example CircleLink/SupabaseSecrets.plist
```

See [SUPABASE_SETUP.md](CircleLink/App/SUPABASE_SETUP.md). Without this file, **text chat still works**; image upload fails with a clear error.

3. In Xcode: press **⌘R** (Run).

On launch, console should show: `[CircleLink] Firebase configured.`

---

## Backend setup (where to look)

| Topic | Doc |
|---|---|
| Firebase Auth, Firestore, FCM, rules | [CircleLink/App/FIREBASE_SETUP.md](CircleLink/App/FIREBASE_SETUP.md) |
| Supabase Storage (`chat-images`) | [CircleLink/App/SUPABASE_SETUP.md](CircleLink/App/SUPABASE_SETUP.md) |
| Push worker (Firestore → FCM) | [websocket-server/README.md](websocket-server/README.md) |

**Important:** stay on Firebase **Spark**. Do **not** deploy `functions/` (that needs Blaze). Push runs in `websocket-server/`.

---

## How data flows (simple)

```
User action
  → View (SwiftUI / UIKit)
  → ViewModel (@MainActor)
  → Repository protocol
  → Firebase (Auth / Firestore) or Supabase (images only)
  → result back to ViewModel
  → UI updates
```

There is **no UseCase layer** in this MVP. Dependencies are wired in `AppDependencies`.

More detail: [ARCHITECTURE.md](ARCHITECTURE.md).

---

## Phases

| Phase | What | Status |
|---|---|---|
| 0–2 | App shell, Firebase auth, age gate | Done |
| 3 | Profile setup / edit, avatars | Done |
| 4 | WebSocket server foundation (iOS client later removed) | Done |
| 5 | Communities (join / leave) | Done |
| 6 | UIKit chat + Supabase image upload | Done |
| 7–8 | Live messaging → chat list + Connect | Done |
| 9 | FCM push + deep links | Done |
| 10 | Stabilize MVP, a11y, remove iOS WebSocket | Done |
| 11 | ViewModel unit tests (Swift Testing) | Done |
| **12** | **Junior docs (this)** | **In progress** |
| 13 | UI polish | Next |
| 14+ | Product features | Later |

---

## Read next

| Doc | For |
|---|---|
| [ARCHITECTURE.md](ARCHITECTURE.md) | Layers, realtime, push, rules |
| [websocket-server/README.md](websocket-server/README.md) | FCM push worker |
| [CircleLink/App/FIREBASE_SETUP.md](CircleLink/App/FIREBASE_SETUP.md) | Firebase Auth / Firestore / FCM |
| [CircleLink/App/SUPABASE_SETUP.md](CircleLink/App/SUPABASE_SETUP.md) | Chat image storage |
