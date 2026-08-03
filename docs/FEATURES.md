# CircleLink — Feature Flows (Junior)

Short “what happens when you tap” notes.  
Layers: **View → ViewModel → Repository** (no UseCase layer in MVP).

Also read: [ARCHITECTURE.md](../ARCHITECTURE.md) · [DESIGN.md](../DESIGN.md) (before UI work).

---

## App shell (routes)

| Piece | What it does | Who owns it | Lifecycle |
|---|---|---|---|
| `AppDependencies` | Creates repos + ViewModel factories | App | Once at launch |
| `AppCoordinator` | Root route + tabs + deep links | App | Lives for app life |
| `MainTabView` | Communities / Chats / Connect / Profile | Presentation | While `route == .mainTab` |

**Route chain after sign-in**

```
auth → ageGate (if ageConfirmedAt == nil)
     → profileSetup (if profile incomplete)
     → mainTab
```

---

## 1. Auth + session restore

| | |
|---|---|
| **What** | Sign in / sign up; restore session on launch |
| **Who** | `AuthView` / `AuthViewModel` → `AuthRepository` (+ Keychain) |
| **Why deps** | Firebase Auth for credentials; Keychain for ID token; `UserRepository` for profile restore |

```
User taps Sign In / Sign Up
  → AuthView
  → AuthViewModel
  → none — VM → AuthRepository
  → Firebase Auth (+ KeychainTokenStorage)
  → User
  → onAuthenticated → AppCoordinator.applyRoute
  → Age Gate / Profile Setup / Main tabs
```

**Cold start:** `AppCoordinator.bootstrapIfNeeded` → `restoreAuthenticatedProfile` → same route rules.

---

## 2. Age gate

| | |
|---|---|
| **What** | User confirms 18+ once |
| **Who** | `AgeGateView` / `AgeGateViewModel` → `UserRepository` |
| **Why deps** | Writes `ageConfirmedAt` on `users/{uid}` |

```
User checks box + Continue
  → AgeGateView
  → AgeGateViewModel.confirmAge
  → none — VM → UserRepository
  → Firestore users/{uid}
  → fetchProfile
  → onAgeConfirmed → AppCoordinator
  → Profile Setup or Main tabs
```

---

## 3. Profile setup / edit

| | |
|---|---|
| **What** | Display name, 3–5 interests, avatar (base64 JPEG in Firestore) |
| **Who** | `ProfileSetupView` / `ProfileView` / `ProfileEditView` → `ProfileViewModel` → `UserRepository` |
| **Why deps** | Profile is stored only on the user document (no Firebase Storage for avatars) |

```
User saves profile
  → ProfileSetupView or ProfileEditView
  → ProfileViewModel
  → none — VM → UserRepository.updateProfile
  → Firestore users/{uid} (avatarBase64 optional)
  → User
  → saveState / onProfileSaved
  → UI shows saved profile (or leaves setup → Main tabs)
```

**Peer profile:** `PeerProfileSheet` / `PeerProfileViewModel` loads another user + Connect relationship (no UseCase).

---

## 4. Communities

| | |
|---|---|
| **What** | List, search, create, join/leave, open group chat |
| **Who** | `CommunitiesListView` / `CreateCommunitySheet` / `CommunityDetailView` + VMs → `CommunityRepository` (+ `ChatRepository` for group chat) |
| **Why deps** | Communities live in Firestore; group chat is a separate `chats` doc |

**Create**

```
User fills Create sheet + submits
  → CreateCommunitySheet
  → CommunitiesViewModel.createCommunity
  → none — VM → CommunityRepository.createCommunity
  → Firestore communities/{id} + members/{uid} (creator = admin)
  → Community
  → list state updates
  → UI shows new community
```

**Join / leave / group chat**

```
User taps Join / Leave / Open group chat
  → CommunityDetailView
  → CommunityDetailViewModel
  → none — VM → CommunityRepository / ChatRepository
  → Firestore members + memberCount; leave also leaveGroupChat first
  → reload community + members
  → UI updates membership / opens Chats tab via AppCoordinator
```

---

## 5. Connect

| | |
|---|---|
| **What** | Discover deck, Like/Pass, Liked You, Matches, open DM |
| **Who** | `ConnectView` + `ConnectViewModel` → `ConnectionRepository`, `ChatRepository`, etc. |
| **Why deps** | Matching is `connectionRequests`; chat is created only when opening a DM |

```
User Likes a candidate
  → ConnectView / Discover deck
  → ConnectViewModel.sendConnect
  → none — VM → ConnectionRepository.sendConnect
  → Firestore connectionRequests/{pairKey}
  → reload candidates / incoming
  → deck advances

User Accepts a request
  → Liked You
  → ConnectViewModel.respond(accept: true)
  → ConnectionRepository.respond
  → Firestore status → accepted
  → matched list updates

User opens chat with a match
  → Matches
  → ConnectViewModel.openChat
  → ChatRepository.createDirectChat
  → Firestore chats + chatRefs
  → onOpenChat(chatId) → AppCoordinator → Chats tab + push ChatThreadRoute
```

**Pass** is session-only (local set) — not written to Firestore.

---

## 6. Chat list

| | |
|---|---|
| **What** | Visible chats, search, mute, hide/unhide, leave, open thread |
| **Who** | `ChatListView` / `HiddenChatsView` / `ChatsViewModel` → `ChatRepository` |
| **Why deps** | Per-user flags live under `users/{uid}/chatRefs/{chatId}` |

```
User opens Chats tab
  → ChatListView
  → ChatsViewModel.loadChats
  → none — VM → ChatRepository.fetchOrganizedChats
  → Firestore chatRefs (+ chat docs)
  → ViewState<[ChatSummary]> + hiddenChats
  → list / empty / error UI

User mutes or hides
  → context actions
  → ChatsViewModel.setMuted / hideChat
  → ChatRepository
  → chatRefs update
  → optimistic list update (reload on failure)
```

Opening a row (or deep link) sets `pendingChatRoute` → navigation push to `ChatThreadView`.

---

## 7. Live messaging + images

| | |
|---|---|
| **What** | History, send text/image, live updates |
| **Who** | `ChatThreadView` → UIKit `ChatViewController` → `ChatViewModel` → `ChatRepository` (+ Supabase for images) |
| **Why deps** | Messages in Firestore; image bytes in Supabase Storage; UIKit chat stays isolated under `Chat/` |

**Send**

```
User taps Send
  → ChatViewController / InputBar
  → ChatViewModel.send
  → none — VM → ChatRepository.sendMessage
  → optional Supabase upload → Firestore message write
  → optimistic row → sent / failed
  → MessageCell updates
```

**Receive (foreground)**

```
Peer writes Firestore message
  → ChatRepository.observeLiveMessages (snapshot listener)
  → AsyncStream<Message>
  → ChatViewModel.handleLiveMessage (dedup by id / clientMessageId)
  → messages array updates
  → UIKit list refreshes
```

Observation starts after history load (`onAppear`); cancel on `onDisappear` / `deinit` removes the listener.

---

## 8. Moderation (report / block)

| | |
|---|---|
| **What** | Report or block a peer (direct chat / Connect) |
| **Who** | Chat / Connect UIs → VM → `ModerationRepository` |
| **Why deps** | Reports and blocks are Firestore paths separate from chat messages |

```
User reports or blocks
  → Chat / Connect UI
  → ChatViewModel or ConnectViewModel
  → none — VM → ModerationRepository
  → Firestore reports/ or users/{uid}/blocked/{peerId}
  → success / error message
  → UI alert; block may dismiss chat / filter Connect
```

---

## 9. Settings

| | |
|---|---|
| **What** | Notification preference + About version |
| **Who** | `SettingsView` / `SettingsViewModel` → `PushNotificationHandler` |
| **Why deps** | Push permission and FCM token live in the push handler, not in a repository |

```
User opens Settings (from Profile) / toggles notifications
  → SettingsView
  → SettingsViewModel.setNotificationsEnabled
  → none — VM → PushNotificationHandler
  → system permission + users/{uid}.fcmToken (via UserRepository inside handler)
  → notificationsEnabled / hint
  → toggle + copy update
```

Opened via `SettingsRoute` from `ProfileView`.

---

## 10. Push deep links

| | |
|---|---|
| **What** | Tap notification → Chat or Connect tab |
| **Who** | `AppDelegate` → `PushNotificationHandler` → `AppCoordinator` |
| **Why deps** | Only the coordinator owns root navigation |

```
User taps FCM notification
  → AppDelegate (UNUserNotificationCenter)
  → PushNotificationHandler.parse → PushDeepLink
  → AppCoordinator.handleDeepLink
  → .newMessage → Chats tab + pendingChatRoute
    .connectionRequest / .connectionAccepted → Connect tab
  → UI navigates when route == mainTab (else pending until ready)
```

Push **sending** is the Node worker in `websocket-server/` — see that README. iOS does not use WebSocket for chat.
