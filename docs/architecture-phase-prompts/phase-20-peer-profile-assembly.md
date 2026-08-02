# Phase 20 — PeerProfile assembly cleanup (DI)

You are a senior iOS engineer working in the CircleLink repo.

## Goal

Stop assembling Peer Profile in inconsistent ways. Composition root / factory should own ViewModel creation; production Views shouldn’t embed large preview repository fakes.

## Why

- `PeerProfileSheet` constructs `PeerProfileViewModel` from repositories.
- Preview/mock repository code (~40 lines) lives in the production presentation file.
- `AppDependencies` already has `makePeerProfileSheet` / `makePeerProfileViewModel` — usage is inconsistent.

## Context

- `Features/Profile/PeerProfileSheet.swift`
- `Features/Profile/PeerProfileView.swift` / `PeerProfileViewModel.swift`
- `App/AppDependencies.swift`
- Call sites that present peer profile (Connect, Chat, Communities, etc.)
- Tests: add `PeerProfileViewModelTests` if missing (keep small)

## Scope

1. Standardize: callers use `AppDependencies.makePeerProfileSheet` / make VM factory (or closures already injected through MainTab).
2. Sheet/View take an already-built VM (or a `@StateObject` wrapper created once from factory) — match existing project patterns for Chat/Community detail.
3. Move preview-only fakes to `#Preview` support / test mocks; out of production type body if possible.
4. Don’t change peer relationship product rules except as needed for DI.

## Out of scope

- Connect VM split
- Full Profile redesign
- Changing connection repository
- Commit / push / PR unless user asks

## Process

1. Grep all PeerProfile presentation call sites.
2. Branch: `phase-20-peer-profile-assembly`.
3. Unify wiring; build; optional small VM tests.

## Acceptance criteria

- [ ] No ad-hoc repository → VM assembly inside random feature Views (except composition root / intentional factory)
- [ ] Preview mocks not cluttering production logic
- [ ] Peer profile still opens from existing entry points
- [ ] Build passes

## Data flow

User taps peer → feature View calls injected factory → `PeerProfileViewModel` → UserRepository + ConnectionRepository → state → PeerProfileView
