# CircleLink — Architecture

Community messenger MVP (iOS 16+, SwiftUI + UIKit Chat).

## Layers

| Layer | Responsibility | Examples |
|---|---|---|
| **App** | Lifecycle, DI composition, root navigation, push, WebSocket lifecycle | `AppDependencies`, `AppCoordinator` |
| **Presentation** | UI rendering, user input | SwiftUI Views, `ChatViewController` |
| **Domain** | Business models, repository protocols | `User`, `ChatRepository` |
| **Data** | Firebase, WebSocket, Keychain implementations | `FirestoreChatRepository`, `WebSocketClient` |
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
3. **No WebSocket in UI** — connection lifecycle managed in App layer; Chat uses `ChatRepository`
4. **Inject dependencies** — no `Firestore.firestore()` inside screens
5. **Domain stays pure** — Domain imports only `Foundation` (no Firebase, UIKit, SwiftUI)
6. **WebSocket reconnect** — handled outside UI layer (App / Data)
7. **Firestore first** — write to Firestore (source of truth), then WebSocket broadcast

## Real-Time Split

| Channel | Role | When |
|---|---|---|
| **Firestore** | Persistence, history, offline sync | Always |
| **WebSocket** | Instant delivery | Foreground only |
| **FCM** | Push notifications | Background |

## Project Structure

```
App/           — AppDelegate, AppDependencies, AppCoordinator
Features/      — Auth, Profile, Communities, Connect, ChatList (SwiftUI)
Chat/          — UIKit chat module (isolated)
Domain/        — Models, Repository protocols
Data/          — Firebase, Network, Keychain
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
  → ChatViewController
  → ChatViewModel.send(text:)
  → optimistic UI (MessageStatus.sending)
  → ChatRepository.sendMessage()
      → Firestore write
      → WebSocket broadcast
  → update status: sent / failed
```

## Testing

- Mock repository protocols for ViewModel tests
- Firebase emulator or mocks for Repository tests
- Protocol-based design enables testability without UI
