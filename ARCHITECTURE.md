# CircleLink — Architecture

Community messenger MVP (iOS 16+, SwiftUI + UIKit Chat).

## Layers

| Layer | Responsibility | Examples |
|---|---|---|
| **App** | Lifecycle, DI composition, root navigation, push | `AppDependencies`, `AppCoordinator` |
| **Presentation** | UI rendering, user input | SwiftUI Views, `ChatViewController` |
| **Domain** | Business models, repository protocols, targeted use cases | `User`, `ChatRepository`, `LeaveCommunityUseCase` |
| **Data** | Firebase, Supabase, Keychain implementations | `FirestoreChatRepository`, `SupabaseChatImageStorage` |
| **Shared** | Cross-cutting utilities | `ViewState`, `ImageLoader` |

## Dependency Direction

```
View → ViewModel → (UseCase?) → Repository protocol ← Data implementation
```

- ViewModels are `@MainActor`
- UseCases only for multi-repo workflows (confirm age, leave community, open community chat). Everything else stays ViewModel → Repository.
- Manual DI via `AppDependencies` (composition root)

**Who owns what**

| Piece | Owner | Lifecycle |
|---|---|---|
| `AppDependencies` | App | Created at launch; holds concrete repos |
| ViewModel | Screen / feature | Lives with the screen; cancelled on disappear |
| UseCase (targeted) | Domain | Stateless; created in factories; orchestrates 2+ repos |
| Repository protocol | Domain | Stable contract; no Firebase types |
| Firebase / Supabase impl | Data | Injected once; used by ViewModels / UseCases |

## Rules

1. **No Firebase in UI** — Views and ViewControllers never call Firestore, Auth, or Storage directly
2. **No Keychain in UI** — token access only through `SecureTokenStorage`
3. **Chat realtime via repository** — screens call `ChatRepository.observeLiveMessages`; they never attach Firestore listeners themselves
4. **Inject dependencies** — no `Firestore.firestore()` inside screens
5. **Domain stays pure** — Domain imports only `Foundation` (no Firebase, UIKit, SwiftUI). Feed-row / view-data composition (e.g. `CommunityPostItem`) lives in Features, not Domain. Domain models / `ImageCompressor` are marked `nonisolated` because the target defaults to MainActor isolation (`SWIFT_DEFAULT_ACTOR_ISOLATION`).
6. **Single source of truth for messages** — Firestore documents only (no hybrid WebSocket + Firestore delivery for the same messages)
7. **Every listener has a matching remove** — `addSnapshotListener` registration is removed when the `AsyncStream` terminates
8. **Single image compress** — UI passes original/picked bytes. Chat/community upload paths compress once in Data (`ImageCompressor` in `Shared/`, off MainActor). Profile avatar compresses once in `ProfileViewModel` (base64 on `User`, also off MainActor). Policy: avatar ≤256px / ~0.55 JPEG / 120 KB; chat & community ≤1200px / ~0.7 JPEG / 500 KB.

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
  → ChatRepository.fetchChatThreadMetadata (not ChatsViewModel list state)
  → pendingChatRoute → ChatList / Connect tab
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
  App/           — AppDelegate, AppDependencies, AppCoordinator, push
  Features/      — Auth, AgeGate, Profile, Communities, Connect, ChatList (SwiftUI)
  Chat/          — UIKit chat module (isolated)
  Domain/        — Models, Repository protocols
  Data/
    Firebase/    — Auth + Firestore repos/mappers
    Supabase/    — chat image upload only
    Keychain/    — token storage
    Stubs/       — stub repos
  Shared/        — ViewState, ImageCompressor, ImageLoader, helpers
CircleLinkTests/ — ViewModel unit tests + mocks (Phase 11)
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

- Phase 11: ViewModel unit tests in `CircleLinkTests/` (Swift Testing + mock repositories)
- Mock repository protocols — no Firebase needed for ViewModel tests
- Protocol-based design keeps UI and network out of unit tests
