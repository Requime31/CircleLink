# Phase 14 — Async Task ownership: Communities

You are a senior iOS engineer working in the CircleLink repo.

## Goal

Bring Communities ViewModels to the same Task/cancellation standard. Scope = Communities feature only.

## Why

`CommunitiesViewModel` and `CommunityFeedViewModel` already own some tasks; `CommunityDetailViewModel` load/join/leave/open-chat often do not. Overlapping membership actions and repeated `load()` can race.

## Standard (same as phase 12)

Owned tasks, cancel on overlapping load, `checkCancellation`, ignore cancel errors, `defer` for in-flight membership flags, weak self.

## Context

- `Features/Communities/CommunitiesViewModel.swift`
- `Features/Communities/CommunityDetailViewModel.swift`
- `Features/Communities/CommunityFeedViewModel.swift`
- Related views only if needed to stop creating unstructured Tasks incorrectly
- Tests: Communities / CommunityDetail (+ Feed if present)
- If phase 7 UseCases exist, call them from owned tasks

## Scope

1. `CommunityDetailViewModel`: own load + membership/open-chat tasks; prevent parallel join/leave; cancel stale load.
2. Align Feed/List with the standard (cancel in `deinit` or explicit `onDisappear` if missing; avoid strong self leaks).
3. Prefer parallel fetch for independent detail data (community + members) **only if** already safe / small win — don’t expand into performance rewrite.
4. Add at least one stale-load or in-flight membership test.

## Out of scope

- Connect / Chat / Auth async
- Feed UI redesign
- Moving `CommunityPostItem` (phase 8)
- Commit / push / PR unless user asks

## Process

1. Branch: `phase-14-async-communities`.
2. Detail VM first (highest risk), then Feed/List gaps.
3. Build + run Communities tests.

## Acceptance criteria

- [ ] Detail membership actions cannot overlap unsafely
- [ ] Stale detail load cannot overwrite newer state
- [ ] Feed cancel-on-disappear still works
- [ ] Tests cover one race/in-flight case
- [ ] Build passes
