# Phase 18 — Surface silent errors (Chat list / Chat / Connect)

You are a senior iOS engineer working in the CircleLink repo.

## Goal

Stop swallowing important failures as empty success. Add minimal user-visible or state-visible error handling for a **small fixed list** of call sites. Do not invent a global error framework.

## Why

Audit found:

- `ChatsViewModel.fetchConversationPreview` → `[]` on any error (looks like empty chat)
- `ChatViewModel.loadParticipants` swallows errors
- `ConnectViewModel.loadBlockedUsers` can keep stale data with no degraded signal
- Live listener failures often only `print` in DEBUG

Silent failures make bugs look like “empty product state”.

## Context

- `Features/ChatList/ChatsViewModel.swift`
- `Chat/ChatViewModel.swift`
- `Features/Connect/ConnectViewModel.swift` (or split VMs)
- Views that show these states
- Prefer after list dedupe (13) / chat async (15) / connect async (16), but can be done carefully alone

## Scope (only these)

1. **Conversation preview:** distinguish empty vs failed (e.g. optional error per chat, or one `previewError` + retry). Don’t break happy path.
2. **Chat participants:** surface failure somehow (banner/state) or keep last good + error flag — justify UX-simple choice.
3. **Connect blocked-users load:** don’t fail the whole Connect dashboard if avoidable; but don’t pretend block filter is fresh if load failed (flag / retry).
4. Live listener: at least set a recoverable error state or one-shot message if stream ends with failure — only if repository API allows without huge rewrite. If `AsyncStream` cannot surface errors, document follow-up (e.g. `AsyncThrowingStream`) and do the other three.

## Out of scope

- Redesigning all empty states to `CLEmptyState` (separate optional phase — ask user)
- Analytics/crash reporting pipeline
- Changing every `try?` in the app
- Commit / push / PR unless user asks

## Process

1. Branch: `phase-18-surface-silent-errors`.
2. Propose the minimal state fields per VM first.
3. Implement + update tests for “error ≠ empty”.

## Acceptance criteria

- [ ] Preview failure is not identical to empty conversation
- [ ] Participants failure is observable in state/UI
- [ ] Blocked-users failure doesn’t silently look fully healthy
- [ ] Tests cover at least preview or participants error ≠ empty
- [ ] Build passes
