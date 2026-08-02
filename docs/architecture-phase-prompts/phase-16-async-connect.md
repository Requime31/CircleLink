# Phase 16 — Async Task ownership: Connect (only)

You are a senior iOS engineer working in the CircleLink repo.

## Goal

Fix Task ownership / stale loads / overlapping actions in Connect presentation code only. Do **not** redesign Connect UI and do **not** re-do the full VM split unless phase 5 is incomplete and a tiny seam is required.

## Why

Connect dashboard `load()` can be triggered from multiple child screens; sections load sequentially; candidate loads use generation tokens but other sections may not. Actions (accept/decline/pass/open chat) can overlap without clear guards.

## Context

- `Features/Connect/ConnectViewModel.swift` and/or split VMs from phase 5
- Connect views that spawn `Task { await viewModel… }`
- Tests: `ConnectViewModelTests` (+ new suites if split)
- Prefer after phase 2 (batch profiles) and phase 5 (split). If still one god VM, only add task ownership — don’t split here.

## Scope

1. Own a root dashboard load task; cancel on re-load.
2. Keep/extend generation tokens or cancellation for candidates + inbox/matches enrichment.
3. In-flight guards for accept/decline/pass/block (per-item or global — justify).
4. Ensure open-chat doesn’t double-create on double tap.
5. Tests: double `load()` stale-safe; one action in-flight guard.

## Out of scope

- Splitting Connect into multiple VMs (phase 5)
- UseCases for Connect (unless already present)
- Moderation product changes
- N+1 batching (phase 2) — re-apply only if missing
- Commit / push / PR unless user asks

## Process

1. Branch: `phase-16-async-connect`.
2. List current async entry points.
3. Implement minimal ownership; build + Connect tests.

## Acceptance criteria

- [ ] Overlapping dashboard loads cannot corrupt state
- [ ] Critical actions have in-flight protection
- [ ] Existing Connect behaviors still pass tests
- [ ] Build passes
