# CircleLink — Architecture

Community messenger MVP (iOS 16+, SwiftUI + UIKit Chat).

## Layers

| Layer | Responsibility | Examples |
|---|---|---|
| **App** | Lifecycle, DI composition, root navigation, push | `AppDependencies`, `AppCoordinator` |
| **Presentation** | UI rendering, user input | SwiftUI Views, `ChatViewController` |
| **Domain** | Business models, repository protocols | `User`, `ChatRepository` |
| **Data** | Firebase, Keychain implementations | `FirestoreChatRepository` |
| **Shared** | Cross-cutting utilities | `ViewState`, `ImageLoader` |

## Dependency Direction

```
View → ViewModel → Repository protocol ← Data implementation
```

- ViewModels are `@MainActor`
- No UseCase layer in MVP — ViewModel calls Repository directly
- Manual DI via `AppDependencies` (composition root)

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
  → Chat sheet / Connect tab
```

- Permission is requested after the first successful message send or Connect — not on launch.
- Token stored at `users/{userId}.fcmToken` (not part of the `User` domain model).
- **Server (Spark / no Blaze):** `websocket-server` Firestore listeners → FCM. See `websocket-server/README.md`.
- Cloud Functions under `functions/` are **not used** (would require Blaze).

### Branch split (realtime)

| Branch | Realtime path |
|---|---|
| **`websocketlocal`** | WebSocket + local/Railway Node server (frozen pre-migration baseline) |
| **`firebaselisteners`** | Firestore `addSnapshotListener` on `chats/{chatId}/messages` only |

WebSocket Swift files / `websocket-server/` may still exist in the tree on `firebaselisteners` but are **unwired** from chat. Active WebSocket chat lives on `websocketlocal`.

## Project Structure

```
App/           — AppDelegate, AppDependencies, AppCoordinator
Features/      — Auth, Profile, Communities, Connect, ChatList (SwiftUI)
Chat/          — UIKit chat module (isolated)
Domain/        — Models, Repository protocols
Data/          — Firebase, Network (legacy WS unused on firebaselisteners), Keychain
Shared/        — ViewState, helpers
Tests/         — ViewModel and Repository tests
```

## State Management

ViewModels expose `@Published` / `@Observable` state using `ViewState<T>`:

- `idle` → initial
- `loading` → fetch in progress
- `loaded(T)` → success with data
- `empty` → no data
- `error(String)` → failure message

All UI updates happen on `@MainActor`.

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

- Mock repository protocols for ViewModel tests
- Firebase emulator or mocks for Repository tests
- Protocol-based design enables testability without UI
