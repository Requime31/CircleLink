# CircleLink — Architecture

Community messenger MVP (iOS 16+, SwiftUI + UIKit Chat).

Junior feature flows (tap → UI update): [docs/FEATURES.md](docs/FEATURES.md).

## Layers

| Layer | Responsibility | Examples |
|---|---|---|
| **App** | Lifecycle, DI composition, root navigation, push | `AppDependencies`, `AppCoordinator`, `PushNotificationHandler` |
| **Presentation** | UI rendering, user input | SwiftUI Views, `ChatViewController` |
| **Domain** | Business models, repository protocols | `User`, `ChatRepository` |
| **Data** | Firebase, Supabase, Keychain implementations | `FirestoreChatRepository`, `SupabaseChatImageStorage` |
| **Shared** | Cross-cutting utilities | `ViewState`, `ImageLoader`, `CLTheme` |

## Dependency Direction

```
View → ViewModel → Repository protocol ← Data implementation
```

- ViewModels are `@MainActor` and use `ObservableObject` + `@Published`
- No UseCase layer in MVP — ViewModel calls Repository directly
- Manual DI via `AppDependencies` (composition root)

**Who owns what**

| Piece | Owner | Lifecycle |
|---|---|---|
| `AppDependencies` | App | Created at launch; holds concrete repos |
| `AppCoordinator` | App | Owns root route, tabs, deep links |
| ViewModel | Screen / feature | Lives with the screen; cancel work on disappear |
| Repository protocol | Domain | Stable contract; no Firebase types |
| Firebase / Supabase impl | Data | Injected once; used by ViewModels |

### Repository map

| Protocol | Typical impl | Used for |
|---|---|---|
| `AuthRepository` | `FirebaseAuthRepository` | Sign in / out, current user |
| `UserRepository` | `FirestoreUserRepository` | Profile, age, FCM token fields |
| `CommunityRepository` | `FirestoreCommunityRepository` | List / create / join / leave |
| `ConnectionRepository` | `FirestoreConnectionRepository` | Connect requests + matches |
| `ChatRepository` | `FirestoreChatRepository` | Chats, messages, mute/hide/leave |
| `ChatImageStorage` | `SupabaseChatImageStorage` | Chat image upload only |
| `ModerationRepository` | `FirestoreModerationRepository` | Report / block |
| `SecureTokenStorage` | `KeychainTokenStorage` | Firebase ID token |

## Rules

1. **No Firebase in UI** — Views and ViewControllers never call Firestore, Auth, or Storage directly
2. **No Keychain in UI** — token access only through `SecureTokenStorage`
3. **Chat realtime via repository** — screens call `ChatRepository.observeLiveMessages`; they never attach Firestore listeners themselves
4. **Inject dependencies** — no `Firestore.firestore()` inside screens
5. **Domain stays pure** — Domain imports only `Foundation` (no Firebase, UIKit, SwiftUI)
6. **Single source of truth for messages** — Firestore documents only (no hybrid WebSocket + Firestore delivery for the same messages)
7. **Every listener has a matching remove** — `addSnapshotListener` registration is removed when the `AsyncStream` terminates

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
  → Chats tab + pendingChatRoute  OR  Connect tab
```

- Permission is requested when the user reaches the main tabs after auth / onboarding — not on cold launch.
- Token stored at `users/{userId}.fcmToken` (not part of the `User` domain model).
- **Server (Spark / no Blaze):** `websocket-server` Firestore listeners → FCM. See `websocket-server/README.md`.
- Cloud Functions under `functions/` are **not used** (would require Blaze).

### Realtime path (current)

Chat delivery uses **Firestore `addSnapshotListener`** on `chats/{chatId}/messages`.
The iOS WebSocket client was removed in Phase 10. `websocket-server/` remains for the **FCM push worker** only (not for chat transport).

Historical baseline: branch `websocketlocal` still has the old WebSocket chat path.

## Project Structure

```
CircleLink/
  App/           — AppDelegate, AppDependencies, AppCoordinator, push, setup docs
  Features/      — Auth, AgeGate, Profile, Communities, Connect, ChatList, Settings (SwiftUI)
  Chat/          — UIKit chat module (isolated)
  Domain/        — Models, Repository protocols
  Data/
    Firebase/    — Auth + Firestore repos/mappers, ImageCompressor
    Supabase/    — chat image upload only
    Keychain/    — token storage
    Network/     — small concurrency helpers
    Stubs/       — stub repos (previews / local stand-ins)
  Shared/        — ViewState, ImageLoader, design tokens, helpers
CircleLinkTests/ — ViewModel unit tests + mocks (Phase 11)
websocket-server/ — Node FCM push worker (Spark)
functions/       — UNUSED Blaze-era reference (do not deploy)
```

## State Management

ViewModels expose `@Published` state. List/detail screens usually use `ViewState<T>`:

- `idle` → initial
- `loading` → fetch in progress
- `loaded(T)` → success with data
- `empty` → no data
- `error(String)` → failure message

Chat thread uses its own `ChatViewModel.LoadState` plus a `messages` array (optimistic send).

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

Per-feature short flows: [docs/FEATURES.md](docs/FEATURES.md).

## Data Flow Example (Send Message)

```
User taps Send
  → ChatViewController / ChatThreadView
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

Observation starts in `ChatViewModel` after history load / `onAppear` and stops in `onDisappear` / `deinit` (cancels Task → stream termination → `ListenerRegistration.remove()`).

## Testing

- Phase 11: ViewModel unit tests in `CircleLinkTests/` (Swift Testing + mock repositories)
- Mock repository protocols — no Firebase needed for ViewModel tests
- Protocol-based design keeps UI and network out of unit tests
- In Xcode: select the **CircleLink** scheme → **Product → Test** (⌘U)
