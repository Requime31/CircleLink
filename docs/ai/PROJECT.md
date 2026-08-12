# PROJECT.md — CircleLink project knowledge

What this app is, how it is layered, and where important pieces live.

Related: [AGENTS.md](AGENTS.md) · [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md) · [DECISIONS.md](DECISIONS.md) · root [`ARCHITECTURE.md`](../../ARCHITECTURE.md) · root [`README.md`](../../README.md)

---

## What CircleLink is

iOS **community messenger** MVP:

- **Communities** — interest-based groups (join / leave, detail, group chat entry)
- **Chats** — chat list + thread (UIKit chat) + chat info
- **Connect** — discover / matching (“Say Hi”), peer profiles
- **Profile** — owner profile, edit, settings entry, posts, sign out

Also: Auth (Apple / email), Age gate, Profile setup onboarding.

Minimum iOS: **16+**.

---

## Tech stack (verified)

| Area | Choice |
|------|--------|
| UI | **SwiftUI** main tabs + features; **UIKit** chat module (`CircleLink/Chat/`) |
| Auth / DB / listeners | **Firebase** Auth + Firestore (+ Messaging for FCM) |
| Chat / profile images | **Supabase** Storage (SPM `supabase-swift`) |
| Realtime chat on iOS | **Firestore listeners** (not WebSocket client) |
| Push | FCM; Node worker in `websocket-server/` (Spark — Cloud Functions in `functions/` not used for MVP push) |
| DI | Manual composition root: `AppDependencies` |
| Tests | Swift Testing in `CircleLinkTests/` |

SPM packages (from Xcode project): `firebase-ios-sdk` (Core, Auth, Firestore, Messaging), `supabase-swift`.

---

## Architecture layers

```
CircleLink/
  App/        — lifecycle, DI, root navigation, push
  Features/   — SwiftUI feature screens (Auth, tabs, Settings, …)
  Chat/       — UIKit chat (isolated)
  Domain/     — models + repository protocols (Foundation only)
  Data/       — Firebase / Supabase / Keychain / Stubs
  Shared/     — ViewState, design tokens, avatars, helpers
CircleLinkTests/
```

**Dependency direction:**

```
View → ViewModel (@MainActor) → Repository protocol ← Data implementation
```

- **No UseCase layer** in MVP — ViewModels call repositories directly.
- **No Firebase / Keychain in UI** — screens talk to protocols only.
- State often uses `ViewState<T>`: `idle` / `loading` / `loaded` / `empty` / `error`.

More detail: root `ARCHITECTURE.md`.

### Domain repositories (protocols)

`AuthRepository`, `UserRepository`, `CommunityRepository`, `ChatRepository`, `ConnectionRepository`, `ModerationRepository`, `ChatImageStorage`, `ProfileImageStorage`, `ProfilePostRepository`, `SecureTokenStorage`.

---

## Main tabs

Owned by `MainTabView` + `AppCoordinator.MainTab`:

| Tab | Feature folder | Role |
|-----|----------------|------|
| Communities | `Features/Communities/` | List + detail |
| Chats | `Features/ChatList/` + `Chat/` | List / thread / info |
| Connect | `Features/Connect/` | Discover + match actions |
| Profile | `Features/Profile/` (+ `Settings/`) | Owner cabinet |

Tab tint uses `CLColor.primary` (Sunset Clay).

---

## Navigation / coordination

`AppCoordinator` (`@MainActor`, `ObservableObject`) owns **root route** and tab selection:

| Route | Screen |
|-------|--------|
| `bootstrapping` | Loading |
| `auth` | `AuthView` |
| `ageGate` | `AgeGateView` |
| `profileSetup` | `ProfileSetupView` |
| `mainTab` | `MainTabView` |

Flow after launch: Auth → Age gate → Profile setup (if needed) → Main tabs.

Cross-cutting:

- `pendingChatRoute` — open a chat from Connect / community / deep link into the Chats tab
- Push: `AppDelegate` → `PushNotificationHandler` → `AppCoordinator.handleDeepLink` → chat sheet or Connect tab

Feature screens typically use local `NavigationStack` / sheets; coordinator stays the composition root for auth gate + tabs + deep links.

---

## Design system location

- Canonical doc: root [`DESIGN.md`](../../DESIGN.md)
- Agent summary: [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md)
- Swift tokens: `CircleLink/Shared/Design/` (`CLTheme.swift`, empty states, banners, …)
- Stitch screen mocks: see [AGENTS.md](AGENTS.md) / `.cursor/rules/`

---

## Tests

Path: **`CircleLinkTests/`**

- ViewModel unit tests + `Mocks/MockRepositories.swift`
- Framework: **Swift Testing**
- No live Firebase required for these ViewModel tests

Examples: `AuthViewModelTests`, `ChatViewModelTests`, `ConnectViewModelTests`, `CommunitiesViewModelTests`, `ProfileViewModelTests`, `ChatInfoViewModelTests`, `AgeGateViewModelTests`, `PeerProfileViewModelTests`, …

---

## Setup docs (not AI memory)

| Doc | Purpose |
|-----|---------|
| `README.md` | Run app, Spark constraints |
| `ARCHITECTURE.md` | Full architecture |
| `CircleLink/App/FIREBASE_SETUP.md` | Firebase |
| `CircleLink/App/SUPABASE_SETUP.md` | Chat images |
| `websocket-server/README.md` | FCM push worker |
