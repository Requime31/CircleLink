# Phase 22 — Consistent empty/error UI via CLEmptyState

You are a senior iOS engineer working in the CircleLink repo.

## Goal

Reuse `CLEmptyState` (and existing design helpers) for repeated empty/error/retry blocks across feature screens. **Visual consistency only** — no ViewModel architecture changes.

## Why

Communities / Chats / Profile / Connect hand-build similar icon + message + retry UI while `Shared/Design/CLEmptyState.swift` already exists.

## Context

- `Shared/Design/CLEmptyState.swift`
- `Shared/Design/CLTheme.swift`
- `DESIGN.md` — read before UI edits
- Feature views with duplicated empty/error stacks

## Priority order inside this phase

Do in this order; stop after a solid first PR if diff is huge (say so in summary):

1. ChatList (+ Hidden if same pattern)
2. Communities list
3. Connect
4. Profile
5. Others only if still obvious duplication

## Scope

1. Inventory duplicated empty/error/retry blocks (list files in the summary).
2. Replace with `CLEmptyState`; extend the component lightly if needed for a retry action — keep API small.
3. No copy/meaning changes unless DESIGN.md requires.
4. Do not refactor ViewModels except trivial binding tweaks.

## Out of scope

- Fat View structural splits (phases 24+)
- Async / DI refactors
- Brand-new design system
- Commit / push / PR unless user asks

## Process

1. Branch: `phase-22-cl-empty-state`.
2. Read DESIGN.md → implement in priority order.
3. Build.

## Acceptance criteria

- [ ] At least ChatList + Communities use shared empty/error UI
- [ ] DESIGN.md respected
- [ ] Build passes
