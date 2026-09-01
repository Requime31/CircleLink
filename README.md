# CircleLink

iOS community messenger MVP: interest-based communities, Connect matching, and chat.

- **UI:** SwiftUI screens + UIKit chat thread
- **Backend:** Firebase Auth + Firestore (Spark plan)
- **Chat images:** Supabase Storage
- **Realtime chat:** Firestore listeners (not WebSocket on iOS)
- **Push:** the app registers FCM tokens and handles notification taps; no server-side sender is included

Minimum iOS: **16+**.

## Branches

| Branch | Purpose |
|---|---|
| `main` | Canonical, current product state |
| `develop` | Integration branch; currently aligned with `main` |
| `ui-redisign` | Preserved source branch for the completed Sunset Parchment redesign |

Start new work from `develop` unless a task explicitly requires another base. Do not
rewrite or delete `ui-redisign`; it remains the traceable source of the redesign.

---

## Requirements

| What | Why |
|---|---|
| macOS + [Xcode](https://developer.apple.com/xcode/) (recent) | Build and run the app |
| Apple ID / signing | Simulator usually works; device needs a team |
| Firebase project | Auth, Firestore, FCM — see setup below |
| Supabase project (optional for text-only) | Chat image uploads |

---

## Open in Xcode

1. Clone the repo and open the project (not a random folder):

```bash
cd CircleLink
open CircleLink.xcodeproj
```

2. Select the **CircleLink** scheme and an iOS Simulator (e.g. iPhone 16).
3. If SPM packages fail: **File → Packages → Resolve Package Versions**.

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
**Important:** stay on Firebase **Spark**. No Cloud Functions or other push backend is included.

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

## Current product surface

| Area | Implemented behavior |
|---|---|
| Launch/auth | Branded bootstrap animation, Apple/email auth, age gate, profile setup |
| Communities | Discovery, search, create/edit, join/leave, posts, media, members, group chat |
| Chats | Visible/hidden lists, pin/reorder, mute, search, media, info and UIKit thread |
| Connect | Discover, incoming/outgoing requests, matches, direct-chat entry, report/block |
| Profile/settings | Profile posts, appearance, reminders, notifications, legal/help/rating, blocked people |
| Account lifecycle | Soft deactivation and recovery; no physical-cleanup worker is included |
| Backend | Firestore realtime, Supabase image storage, hardened rules/indexes |
| Quality | Swift Testing coverage for ViewModels, data policies and navigation helpers |

---

## Read next

| Doc | For |
|---|---|
| [ARCHITECTURE.md](ARCHITECTURE.md) | Layers, realtime, push, rules |
| [CircleLink/App/FIREBASE_SETUP.md](CircleLink/App/FIREBASE_SETUP.md) | Firebase Auth / Firestore / FCM |
| [CircleLink/App/SUPABASE_SETUP.md](CircleLink/App/SUPABASE_SETUP.md) | Chat image storage |
