# Phase 19 — Split MessageCell (UIKit presentation only)

You are a senior iOS engineer working in the CircleLink repo.

## Goal

Decompose oversized `MessageCell` (~534 LOC) into smaller UIKit subviews/helpers. Behavior and look should stay the same.

## Why

One cell owns layout, bubble content, image loading, retry UI, avatar, reuse cancellation, status rendering. Hard to review and easy to break reuse bugs.

## Context

- `Chat/MessageCell.swift`
- Related: `ChatAppearance.swift`, `ChatMessageItem.swift`, `ImageLoader`
- Used by `ChatViewController`
- No Domain/Data changes expected

## Suggested split (adjust after reading)

- Bubble container / text content
- Image content (load + reuse cancel)
- Avatar
- Status / retry control
- Keep `MessageCell` as assembler configuring subviews from `ChatMessageItem`

## Scope

1. Extract subviews/files under `CircleLink/Chat/`.
2. Preserve reuse cancellation for image loads.
3. No product/UX changes (spacing/colors stay).
4. Don’t migrate cell to SwiftUI.

## Out of scope

- ChatViewModel / repository
- Full chat redesign
- Replacing ImageLoader globally (phase 9 may have started injection — use what’s there)
- Commit / push / PR unless user asks

## Process

1. Branch: `phase-19-split-message-cell`.
2. Map responsibilities in MessageCell first.
3. Extract one subview at a time; build after each.
4. Manual test checklist in summary: text, image, retry, incoming/outgoing, reuse scroll.

## Acceptance criteria

- [ ] `MessageCell.swift` is substantially thinner or a clear assembler
- [ ] No behavior regressions in binding/reuse
- [ ] Build passes
