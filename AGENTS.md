# CircleLink — agent entry

iOS community messenger (iOS 16+). SwiftUI screens + UIKit chat. Firebase Auth / Firestore. Chat images on Supabase Storage. Spark plan — no Cloud Functions.

This file is a **short checklist**. Canonical explanations live in the docs below. Change a rule in `ARCHITECTURE.md` first, then the matching line here.

## Must read

| File | Why |
|---|---|
| [ARCHITECTURE.md](ARCHITECTURE.md) | Layers, folder map, realtime, numbered rules |
| [DESIGN.md](DESIGN.md) | UI — read before any visual work |
| [README.md](README.md) | How to run the app |
| [CircleLink/App/FIREBASE_SETUP.md](CircleLink/App/FIREBASE_SETUP.md) | Auth, Firestore rules, FCM |
| [CircleLink/App/SUPABASE_SETUP.md](CircleLink/App/SUPABASE_SETUP.md) | Chat image bucket |

## Do not

1. No Firebase / Auth / Storage in Views or ViewControllers.
2. No Keychain in Views — only `SecureTokenStorage`.
3. Chat listeners only through `ChatRepository.observeLiveMessages`.
4. Dependencies from `AppDependencies`. No `Firestore.firestore()` in screens.
5. Domain imports `Foundation` only.
6. Messages are Firestore documents only. **Do not bring WebSocket chat back to iOS.** `websocket-server/` is the FCM push worker, not chat transport.
7. Every `addSnapshotListener` is removed when the stream ends.
8. No UseCase layer. ViewModel → repository protocol.
9. Stay on Firebase **Spark**. Do not deploy `functions/`. Do not require Blaze.
10. Before UI work, read `DESIGN.md`. Do not invent colors or spacing.

## Map

Folders, layers, and data flow: [ARCHITECTURE.md](ARCHITECTURE.md) (Project Structure + Layers).

```
View → ViewModel (@MainActor) → Repository protocol → Firebase / Supabase
```

There is no UseCase layer. Tests mock repository protocols in `CircleLinkTests/`.

## Recurring commands

Project skills (committed): `.cursor/skills/`

| Skill | Use when |
|---|---|
| `new-branch` | Start work — create `feature/<short-name>` first |
| `deploy-rules` | Publish Firestore / Firebase Storage rules; Supabase policies |
| `perf-review` | Review the current diff for performance |
| `test` | Run `CircleLinkTests` |
