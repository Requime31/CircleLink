# Phase 10 — Decouple AppCoordinator from ChatsViewModel state

You are a senior iOS engineer working in the CircleLink repo.

## Goal

Stop `AppCoordinator` from reading `ChatsViewModel` loaded state to build deep-link / open-chat routes (title, communityId). Navigation must not depend on whether the chat list finished loading.

## Why

Coordinator currently inspects another screen’s ViewModel state (e.g. `chatsViewModel.state` → find chat → communityId / title). That couples navigation to incidental cache contents and breaks when list is empty/stale/not loaded yet.

## Context

- `CircleLink/App/AppCoordinator.swift` (`openChat`, `chatTitle`, deep link handling)
- Push: `PushNotificationHandler`, `PushDeepLink`
- Chat list: `ChatsViewModel`, `ChatListView`, `pendingChatRoute` / `ChatThreadRoute`
- Possible lookup API on `ChatRepository` / `ChatInfo`
- Docs: `ARCHITECTURE.md` (push deep link flow)

## Scope

1. Identify all coordinator reads of other VMs’ presentation state.
2. Prefer one of:
   - Deep link / open-chat payload already carries title + communityId when known; or
   - Coordinator/async lookup via `ChatRepository` (e.g. fetch chat info/summary by id) before setting `pendingChatRoute`.
3. Keep UX: FCM tap still opens the right chat sheet/stack.
4. Avoid turning Coordinator into a new god object — extract a tiny `ChatRouteBuilding` helper if it helps.
5. Add a focused test if you can test route building without UIKit (pure function / small helper).

## Out of scope

- Full navigation rewrite to TCA/coordinators-per-tab (mention as future)
- Splitting all tab routers in one go
- Push permission UX changes
- Commit / push / PR unless user asks

## Process

1. Propose the new deep-link data flow (short diagram) before coding.
2. Branch: `phase-10-coordinator-deeplink-decouple`.
3. Implement minimal fix → build → reason about cold start when chats list not loaded.
4. Review: race (deep link before auth), MainActor, failure fallback (open chat with default title).

## Acceptance criteria

- [ ] Coordinator does not read `ChatsViewModel.state` for metadata
- [ ] Deep link works even if chat list not loaded
- [ ] Existing tab + pending route wiring still works
- [ ] Build passes

## Target data flow

FCM tap → AppDelegate → PushNotificationHandler → `PushDeepLink` → AppCoordinator.handleDeepLink → (payload or `ChatRepository` lookup) → `pendingChatRoute` → ChatList NavigationStack → Chat screen
