# Phase 13 — Dedupe ChatList: leaveChat + conversation preview

You are a senior iOS engineer working in the CircleLink repo.

## Goal

Remove duplicated leave-chat and conversation-preview logic between Chat list screens / ViewModels. Keep scope inside **ChatList** (+ shared chat list helpers). Do not refactor the whole Chat UIKit module.

## Why

1. `ChatsViewModel.leaveChat` and `ChatInfoViewModel.leaveChat` both call the repository and handle success/failure separately → diverging UX/state.
2. `ChatListView` and `HiddenChatsView` both keep preview cache / loading IDs and call `fetchConversationPreview`.

## Context

- `Features/ChatList/ChatsViewModel.swift`
- `Features/ChatList/ChatInfoViewModel.swift`
- `Features/ChatList/ChatListView.swift`
- `Features/ChatList/HiddenChatsView.swift`
- `Features/ChatList/ChatInfoView.swift`
- Repo: `ChatRepository.leaveChat`
- Tests: add/extend ChatList-related VM tests (may be missing — create focused ones)

## Recommended approach (pick and justify)

**Leave chat**

- Single place for list mutation after leave: preferably `ChatsViewModel` (source of truth for organized chats).
- `ChatInfoViewModel.leaveChat` calls repository (or a tiny helper) and reports success; list refresh/removal is coordinated via callback / shared VM / notification-free explicit closure from the list feature — keep it simple.
- Avoid NotificationCenter unless already used in project.

**Previews**

- Move preview cache + in-flight set into `ChatsViewModel` (or a small `ChatPreviewLoading` helper owned by the list feature).
- Both `ChatListView` and `HiddenChatsView` call the same API.

## Scope

1. Dedupe leave-chat success/error + list update path.
2. Dedupe preview loading/cache.
3. Preserve optimistic mute/hide behavior already in `ChatsViewModel`.
4. Do not change Firestore rules or repository protocol unless necessary.
5. Add tests for leave success removing/updating list state; preview cache hit if easy.

## Out of scope

- `ChatViewModel` send/reconcile (phase 6)
- MessageCell
- Deep links (phase 10)
- Full async pass for Chat (phase 15) — only touch tasks if required by dedupe
- Commit / push / PR unless user asks

## Process

1. Map current leave + preview call sites first.
2. Branch: `phase-13-dedupe-chat-list-flows`.
3. Implement smallest API that removes duplication.
4. Build + tests.

## Acceptance criteria

- [ ] One clear leave-chat orchestration path for list consistency
- [ ] Preview cache/loading not duplicated in two Views
- [ ] Hidden + visible lists still work
- [ ] Build passes
