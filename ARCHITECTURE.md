# CircleLink — Architecture

Community messenger MVP (iOS 16+, SwiftUI + UIKit Chat).

## Layers

| Layer | Responsibility | Examples |
|---|---|---|
| **App** | Lifecycle, DI composition, root navigation, push | `AppDependencies`, `AppCoordinator` |
| **Presentation** | UI rendering, user input | SwiftUI Views, `ChatViewController` |
| **Domain** | Business models, repository protocols | `User`, `ChatRepository` |
| **Data** | Firebase, Supabase, Keychain implementations | `FirestoreChatRepository`, `SupabaseChatImageStorage` |
| **Shared** | Cross-cutting utilities | `ViewState`, `ImageLoader` |

## Dependency Direction

```
View → ViewModel → Repository protocol ← Data implementation
```

- ViewModels are `@MainActor`
- No UseCase layer in MVP — ViewModel calls Repository directly
- Manual DI via `AppDependencies` (composition root)

**Who owns what**

| Piece | Owner | Lifecycle |
|---|---|---|
| `AppDependencies` | App | Created at launch; holds concrete repos |
| ViewModel | Screen / feature | Lives with the screen; cancelled on disappear |
| Repository protocol | Domain | Stable contract; no Firebase types |
| Firebase / Supabase impl | Data | Injected once; used by ViewModels |

## Rules

1. **No Firebase in UI** — Views and ViewControllers never call Firestore, Auth, or Storage directly
2. **No Keychain in UI** — token access only through `SecureTokenStorage`
3. **Chat realtime via repository** — screens call `ChatRepository.observeLiveMessages`; they never attach Firestore listeners themselves
4. **Inject dependencies** — no `Firestore.firestore()` inside screens
5. **Domain stays pure** — Domain imports only `Foundation` (no Firebase, UIKit, SwiftUI)
6. **Single source of truth for messages** — Firestore documents only (no hybrid WebSocket + Firestore delivery for the same messages)
7. **Every listener has a matching remove** — `addSnapshotListener` registration is removed when the `AsyncStream` terminates
8. **Birth date stays private and date-only** — store it only at `users/{uid}/private/account` as Gregorian UTC noon; public profile documents contain derived `age`
9. **Account deactivation is soft and reversible for 30 days** — `users/{uid}` owns `accountState`, `deletionRequestedAt`, and `scheduledDeletionAt`; new social interactions require active participants
10. **Deactivated sessions are recovery-only** — the root coordinator routes them to account recovery before age/profile/main gates; restore refetches the profile before normal routing
11. **Physical account cleanup is external and retryable** — the `websocket-server` CLI claims due profiles transactionally, anonymizes preserved content, deletes private/related records and Auth, then deletes the public profile last
12. **No UseCase layer** — ViewModel calls the repository protocol directly
13. **Firebase Spark only** — do not deploy `functions/` or require Blaze; FCM goes through `websocket-server/`
14. **UI follows DESIGN.md** — read it before any visual work; do not invent colors, spacing, or components

## Real-Time Model

| Channel | Role | When |
|---|---|---|
| **Firestore listeners** | Instant delivery while the app process is alive (chat screen open) | Foreground / process alive |
| **Firestore reads** | History and pagination (`fetchMessages`) | Always |
| **FCM** | Push when app is backgrounded / killed | Node `websocket-server` push worker → Admin Messaging |

Listeners do **not** replace push. If the process is dead, delivery waits for FCM.

### Push / deep links (Phase 9)

```
FCM tap
  → AppDelegate (UNUserNotificationCenter)
  → PushNotificationHandler.parse → PushDeepLink
  → AppCoordinator.handleDeepLink
  → Chat sheet / Connect tab
```

- Permission is requested when the user reaches the main tabs after auth / onboarding — not on cold launch.
- Token stored at `users/{userId}/private/account.fcmToken` (not part of the public `User` document).
- **Server (Spark / no Blaze):** `websocket-server` Firestore listeners → FCM. See `websocket-server/README.md`.
- Cloud Functions under `functions/` are **not used** (would require Blaze).

### Realtime path (current)

Chat delivery uses **Firestore `addSnapshotListener`** on `chats/{chatId}/messages`.
The iOS WebSocket client was removed in Phase 10. `websocket-server/` remains for the **FCM push worker** only (not for chat transport).

Historical baseline: branch `websocketlocal` still has the old WebSocket chat path.

## Project Structure

```
CircleLink/
  App/           — AppDelegate, AppDependencies, AppCoordinator, push
  Features/      — Auth, AgeGate, Profile, Communities, Connect, Settings, ChatList
    Chat/         — UIKit chat thread + SwiftUI wrapper (isolated inside Features)
  Domain/        — Models, Repository protocols
  Data/
    Firebase/    — Auth + Firestore repos/mappers
    Supabase/    — chat image upload only
    Keychain/    — token storage
    Stubs/       — stub repos
  Shared/        — ViewState, helpers
CircleLinkTests/ — Swift Testing suites + mocks
websocket-server/ — Node FCM push worker (Spark)
```

## State Management

ViewModels expose `@Published` / `@Observable` state using `ViewState<T>`:

- `idle` → initial
- `loading` → fetch in progress
- `loaded(T)` → success with data
- `empty` → no data
- `error(String)` → failure message

All UI updates happen on `@MainActor`.

## Data Flow (generic)

```
User action
  → View
  → ViewModel
  → Repository protocol
  → Firebase Auth / Firestore  OR  Supabase Storage (images)
  → Response
  → ViewModel updates @Published / ViewState
  → UI re-renders
```

## Data Flow Example (Send Message)

```
User taps Send
  → ChatViewController / ChatView
  → ChatViewModel.send(text:)
  → optimistic UI (MessageStatus.sending)
  → ChatRepository.sendMessage()
      → optional Supabase image upload
      → Firestore batch write
  → update status: sent / failed
```

## Data Flow Example (Receive Live Message)

```
Peer writes to Firestore
  → addSnapshotListener on chats/{chatId}/messages
  → DocumentChange (.added / .modified)
  → AsyncStream<Message>
  → ChatViewModel.handleLiveMessage (dedup by id + clientMessageId)
  → UI update
```

Observation starts in `ChatViewModel.onAppear` and stops in `onDisappear` / `deinit` (cancels Task → stream termination → `ListenerRegistration.remove()`).

## Testing

- ViewModel and policy tests live in `CircleLinkTests/` (Swift Testing + mock repositories)
- Mock repository protocols — no Firebase needed for ViewModel tests
- Protocol-based design keeps UI and network out of unit tests

## Root navigation and launch

`AppCoordinator` owns the root route: bootstrap → auth/account recovery → age gate →
profile setup → main tabs. Returning authenticated sessions show `LoadingView` while the
profile is restored. Debug builds intentionally keep it visible for three seconds; Release
does not add this delay. The pre-SwiftUI iOS Launch Screen is still system-generated.

Each tab owns one `NavigationStack`. Cross-feature chat entry is expressed as a typed
`ChatThreadRoute`; direct and group routes stay distinct so cached community metadata cannot
change a direct-chat destination.

## Chat security boundary

- Firebase and Supabase SDK traffic uses HTTPS/TLS negotiated by the OS/provider.
- Firestore rules restrict chat reads/writes to authenticated participants or current group members.
- Direct-chat creation uses a deterministic sorted-user-ID document key. A missing chat may be
  read only as a creation probe by a participant in the accepted connection with the same pair key;
  this exception does not authorize reads from a missing chat's message subcollection.
- `users/{uid}/chatRefs/{chatId}.lastMessageAt` mirrors the exact Firestore `Timestamp` stored on
  `chats/{chatId}`. Repository code must not convert that value through `Date`, because rules use
  exact timestamp equality and Firestore nanoseconds may otherwise be lost.
- Message `text` and `lastMessageText` are stored as plaintext fields; CircleLink does **not**
  currently provide end-to-end encryption.
- Supabase chat images currently use returned public URLs.
- The legacy Node WebSocket listener creates HTTP/WS itself and is not the iOS message path;
  production TLS for that endpoint requires an HTTPS/WSS reverse proxy.
