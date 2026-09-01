# PROJECT.md — CircleLink project knowledge

What this app is, how it is layered, and where important pieces live.

Related: [AGENTS.md](AGENTS.md) · [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md) · [DECISIONS.md](DECISIONS.md) · root [`ARCHITECTURE.md`](../../ARCHITECTURE.md) · root [`README.md`](../../README.md)

---

## What CircleLink is

iOS **community messenger** MVP:

- **Communities** — discovery/search, create, join/leave, cover editing, member posts, detail, group chat entry
- **Chats** — visible/hidden lists, pin/reorder, UIKit thread, search/media/info, mute/hide/clear/delete flows
- **Connect** — discovery, incoming/outgoing requests, matches, “Say Hi”, peer profiles, report/block
- **Profile** — owner profile/edit, interests, posts, appearance, reminders, legal/help, blocked people, sign out

Also: Auth (Apple / email), Age gate, Profile setup onboarding.

Minimum iOS: **16+**.

---

## Tech stack (verified)

| Area | Choice |
|------|--------|
| UI | **SwiftUI** main tabs + features; **UIKit** chat module (`CircleLink/Features/Chat/`) |
| Auth / DB / listeners | **Firebase** Auth + Firestore (+ Messaging for FCM) |
| Chat / profile-post / community images | **Supabase** Storage (SPM `supabase-swift`) |
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
    Chat/     — UIKit chat thread under `Features/Chat/`
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

`AuthRepository`, `UserRepository`, `CommunityRepository`, `CommunityPostRepository`, `ChatRepository`, `ConnectionRepository`, `ModerationRepository`, `ChatImageStorage`, `ProfileImageStorage`, `CommunityImageStorage`, `ProfilePostRepository`, `SecureTokenStorage`.

Concrete production implementations are composed in `AppDependencies`: Firebase for auth/Firestore data, Keychain for secure token storage, and Supabase Storage for binary images. User avatars are the exception: compressed JPEG base64 is stored in the Firestore user document.

---

## Main tabs

Owned by `MainTabView` + `AppCoordinator.MainTab`:

| Tab | Feature folder | Role |
|-----|----------------|------|
| Communities | `Features/Communities/` | Discover/create + detail/posts/group chat |
| Chats | `Features/ChatList/` + `Features/Chat/` | Lists + navigation shell / UIKit thread |
| Connect | `Features/Connect/` | Discover + requests + matches + moderation |
| Profile | `Features/Profile/` (+ `Settings/`) | Owner profile/posts/settings |

Tab tint uses `CLColor.primary` (Sunset Clay). Communities/Profile use system large titles,
Connect uses inline navigation chrome, and Chats keeps a static large content header above
its list so pushed Hidden Chats search cannot remove it.

Connect discovery ordering is owned by `ConnectViewModel`. `ConnectDiscoverDeckView` renders
`top` / `next` / `following` directly and owns only transient drag/exit animation state. Passed
IDs are session presentation state: refreshes must not prune them merely because a repository
snapshot temporarily omits a user.

---

## Navigation / coordination

`AppCoordinator` (`@MainActor`, `ObservableObject`) owns **root route** and tab selection:

| Route | Screen |
|-------|--------|
| `bootstrapping` | Loading |
| `auth` | `AuthView` |
| `accountRecovery` | `AccountRecoveryView` |
| `ageGate` | `AgeGateView` |
| `profileSetup` | `ProfileSetupView` |
| `mainTab` | `MainTabView` |

Flow after launch: Auth → Account recovery (deactivated profiles only) → Age gate → Profile setup (if needed) → Main tabs.

Authenticated cold starts enter `bootstrapping` and show `LoadingView`. A three-second
visibility delay is compiled only in Debug for animation review.

Cross-cutting:

- `pendingChatRoute` (`ChatThreadRoute`) — open a chat from Connect / community / push into the Chats tab and preserve optional community context
- Push: `AppDelegate` → `PushNotificationHandler` → `AppCoordinator.handleDeepLink` → Chats route or Connect tab

Feature screens typically use local `NavigationStack` / sheets; coordinator stays the composition root for auth gate + tabs + push deep links. Push destinations are `.newMessage`, `.connectionRequest`, and `.connectionAccepted`; payloads with a target user are rejected if they do not match the active session.

---

## Design system location

- Canonical doc: root [`DESIGN.md`](../../DESIGN.md)
- Agent summary: [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md)
- Swift tokens: `CircleLink/Shared/Design/` (`CLTheme.swift`, empty states, banners, …)
- Optional local Stitch screen mocks: see [AGENTS.md](AGENTS.md) / `.cursor/rules/`

---

## Tests

Path: **`CircleLinkTests/`**

- ViewModel unit tests + `Mocks/MockRepositories.swift`
- Framework: **Swift Testing**
- No live Firebase required for these ViewModel tests

Examples: `AuthViewModelTests`, `ChatViewModelTests`, `ConnectViewModelTests`, `CommunitiesViewModelTests`, `ProfileViewModelTests`, `ChatInfoViewModelTests`, `AgeGateViewModelTests`, `PeerProfileViewModelTests`, …

Additional suites cover account recovery/deletion, birth-date policy, blocked people,
chat ordering/pinning/routes, community content/forms/navigation, reminders, legal/support,
outgoing likes and settings presentation.

## Security posture

- Transport to Firebase/Supabase is TLS via their SDKs and the OS network stack.
- Firestore authorization is enforced by the checked-in `firestore.rules`.
- Chats are not E2EE: message text and previews are server-readable Firestore fields.
- Chat image uploads currently return Supabase public URLs.
- Secrets remain in ignored plist/env files; never place service-role/Admin credentials in iOS.

Direct chat IDs and connection-request pair keys use the same sorted-user-ID format. Creation
first probes the deterministic chat document; Firestore permits a missing-document `get` only
for the two users in the matching accepted connection. Per-user chat preview refs must copy the
parent chat's exact Firestore `Timestamp` so strict rules equality is preserved, including
nanoseconds and legacy-chat normalization.

---

## Setup docs (not AI memory)

| Doc | Purpose |
|-----|---------|
| `README.md` | Run app, Spark constraints |
| `ARCHITECTURE.md` | Full architecture |
| `CircleLink/App/FIREBASE_SETUP.md` | Firebase |
| `CircleLink/App/SUPABASE_SETUP.md` | Supabase image storage (chat, profile posts, communities) |
| `websocket-server/README.md` | FCM push worker |
