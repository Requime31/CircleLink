# Phase 12 — Async Task ownership: Auth / AgeGate / Profile

You are a senior iOS engineer working in the CircleLink repo.

## Goal

Give Auth, AgeGate, and Profile ViewModels clear ownership of async work: cancel stale tasks, ignore cancellation, avoid double-submit races. Do **not** touch Communities / Connect / Chat in this phase.

## Why

These VMs often start work via unstructured `Task { }` in the View, with no `loadTask`/`saveTask` on the VM. Fast double-taps or leaving the screen can race and overwrite state.

## Standard to apply (keep it simple)

For each mutating/load method the VM owns:

1. Store `private var …Task: Task<Void, Never>?` (or separate load/save tasks).
2. Cancel previous task before starting a new one when overlapping is wrong.
3. Use `[weak self]` in long tasks.
4. `try Task.checkCancellation()` after awaits before writing state.
5. Ignore `CancellationError`.
6. Prefer `defer` for in-flight flags (`isSaving`).
7. Views call VM methods; they may still use `.task` / `Task` **only** as a thin trigger — VM owns cancellation.

Do **not** invent a BaseViewModel.

## Context

- `Features/Auth/AuthViewModel.swift` + `AuthView.swift`
- `Features/AgeGate/AgeGateViewModel.swift` + view
- `Features/Profile/ProfileViewModel.swift` (+ setup/edit entry points)
- Tests: Auth / AgeGate / Profile ViewModel tests
- Good reference patterns: `CommunitiesViewModel`, `ChatInfoViewModel`, `CommunityFeedViewModel`

## Scope

1. Auth: sign-in / sign-up paths — guard in-flight, cancel or ignore overlapping submits.
2. AgeGate: confirm-age task ownership + cancel-safe state updates.
3. Profile: load + save task ownership; don’t let stale load overwrite a newer save result (generation token or cancel).
4. Add/adjust 1–2 race/cancellation tests if cheap.
5. Short note in PR/summary: which methods now own tasks.

## Out of scope

- Communities / Connect / Chat async (phases 14–16)
- Image compression off-main (phase 9)
- UseCases (phase 7) — if ConfirmAge already extracted, just call it from owned task
- UI redesign
- Commit / push / PR unless user asks

## Process

1. Branch: `phase-12-async-auth-profile`.
2. One VM at a time; keep build green.
3. Explicit async review before finish.

## Acceptance criteria

- [ ] Auth / AgeGate / Profile VMs own their main Tasks
- [ ] Double-submit cannot leave stuck loading without a path out
- [ ] Cancellation does not apply error UI spuriously
- [ ] Existing tests pass; at least one new cancel/stale or in-flight guard test if practical
- [ ] Build passes
