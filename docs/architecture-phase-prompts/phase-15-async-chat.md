# Phase 15 — Async Task ownership: Chat + ChatList + ChatInfo

You are a senior iOS engineer working in the CircleLink repo.

## Goal

Make Chat-related ViewModels own and cancel their async work consistently. Do not redesign message UI.

## Why

`ChatViewModel` owns the live listener task, but initial load / pagination / send / retry / moderation are often caller-owned unstructured tasks. `ChatsViewModel` uses generation IDs but may not cancel in-flight loads. Overlap causes stale pages and confusing send state.

## Context

- `Chat/ChatViewModel.swift` (+ thin triggers in `ChatViewController` / wrappers)
- `Features/ChatList/ChatsViewModel.swift`
- `Features/ChatList/ChatInfoViewModel.swift` (already has loadTask — fill gaps)
- Tests: `ChatViewModelTests` + list tests if any
- Prefer after phase 6 (extract helpers) and phase 13 (list dedupe), but can proceed if careful

## Scope

1. **ChatViewModel**
   - Own tasks for: initial load, load-more, send (per message or single pipeline — justify), moderation actions as needed.
   - Keep live listener start/stop correct (`onAppear` / `onDisappear` / `deinit`).
   - Cancel stale pagination when chat disappears.
   - Don’t break optimistic send UX.
2. **ChatsViewModel**
   - Own/cancel list load task; keep generation token or replace with cancel+check.
3. **ChatInfoViewModel**
   - Ensure leave has in-flight guard; load cancel already mostly OK.
4. Add tests: cancel initial load / double load doesn’t apply stale; send in-flight guard if practical.

## Out of scope

- Splitting FirestoreChatRepository (phase 4)
- MessageCell split (phase 19)
- Image compression (phase 9)
- Connect
- Commit / push / PR unless user asks

## Process

1. Branch: `phase-15-async-chat`.
2. Propose task map (which method → which Task handle) before big edits.
3. Implement incrementally; keep ChatViewModelTests green.

## Acceptance criteria

- [ ] Leaving chat screen cancels load/pagination/live work appropriately
- [ ] No unstructured fire-and-forget for initial history load
- [ ] List reload cancels/ignores stale results
- [ ] Tests cover at least one cancel/stale case
- [ ] Build passes

## Async checklist (must answer in final review)

- MainActor UI updates
- Task cancellation
- Race on double load
- Retain cycles on long-lived listener task
