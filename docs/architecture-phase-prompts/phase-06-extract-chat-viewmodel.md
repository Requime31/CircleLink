# Phase 6 — Extract helpers from ChatViewModel (keep screen VM)

You are a senior iOS engineer working in the CircleLink repo.

## Goal

Slim down `ChatViewModel` (~447 LOC) by extracting message mapping, send/retry status updates, and live-message reconciliation — without changing the chat product behavior.

## Why

`ChatViewModel` currently mixes: history pagination, live listener lifecycle, participants, optimistic send, retry, dedup/reconcile, display decoration, moderation, chat metadata. Send and retry duplicate `Message` reconstruction. This is hard to test in isolation and easy to break.

## Context

- VM: `CircleLink/Chat/ChatViewModel.swift`
- UIKit: `ChatViewController.swift`, `ChatMessageItem.swift`
- Repo: `ChatRepository` (+ optional `ModerationRepository`)
- Tests: `CircleLinkTests/ChatViewModelTests.swift` (keep green; extend for reconciler if pure)
- Docs: `ARCHITECTURE.md` (optimistic send + live receive flow)

## Suggested extractions types (pure / testable)

1. **Mapper** — `Message` (+ local image) → `ChatMessageItem` / decoration (sender labels etc.)
2. **Reconciler** — apply live events + dedup by `id` / `clientMessageId`
3. **Send pipeline helper** — shared transitions for send + retry (`sending` → `sent` / `failed`)

Keep `ChatViewModel` as the `@MainActor` screen orchestrator that owns tasks and `@Published` state.

## Scope

1. Extract without changing public screen behavior.
2. Reduce duplicated Message rebuild in send/retry.
3. Prefer pure structs/functions for reconciler/mapper so unit tests don’t need Firebase.
4. Improve task ownership only where you touch code (e.g. cancel live task remains correct; consider cancelling load on disappear if safe).
5. Update ChatViewModel tests; add focused tests for reconciler/mapper.

## Out of scope

- Splitting `FirestoreChatRepository` (Phase 4) — may already be done; don’t redo
- Rewriting `MessageCell` / full UIKit layout
- Changing realtime transport
- Image compression pipeline (Phase 9)
- Commit / push / PR unless user asks

## Process

1. Propose type names + file placement under `CircleLink/Chat/`.
2. Branch: `phase-6-extract-chat-viewmodel`.
3. Move logic → keep tests green → add pure-unit tests for dedup edge cases.
4. Explicit async check: cancellation, MainActor UI updates, no retain cycles on listener task.

## Acceptance criteria

- [ ] ChatViewModel noticeably thinner / clearer responsibilities
- [ ] Send + retry share one status-update path
- [ ] Live dedup behavior covered by tests
- [ ] Existing ChatViewModelTests still pass
- [ ] Build passes

## Data flow (send) — should stay the same externally

User taps Send → ChatViewController → ChatViewModel.send → optimistic item → ChatRepository.sendMessage → update status via helper → UI
