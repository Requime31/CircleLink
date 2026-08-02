# Phase 5 — Split ConnectViewModel (god ViewModel)

You are a senior iOS engineer working in the CircleLink repo.

## Goal

Split `ConnectViewModel` (~352 LOC, many repositories, multiple screens) into clearer presentation units **without** rewriting the whole Connect UX.

## Why

One VM currently owns: communities for connect, discovery deck, incoming requests, matches, peer resolution, moderation/block filtering, direct-chat open, navigation callback, multiple load states. That violates “one VM ≈ one screen/scenario” and makes testing/cancellation hard.

## Context

- VM: `CircleLink/Features/Connect/ConnectViewModel.swift`
- Views: `ConnectView.swift`, `ConnectDiscoverDeckView.swift`, `LikedYouView.swift`, `MatchesView.swift`
- Factory: `AppDependencies.makeConnectViewModel`
- Coordinator holds lazy `connectViewModel`
- Tests: `CircleLinkTests/ConnectViewModelTests.swift`
- Prefer Phase 2 (batch profiles) already merged; if not, keep batching or re-apply it.
- Docs: `ARCHITECTURE.md`

## Recommended approach (choose one and justify)

**Option A (preferred for SwiftUI tabs):**  
- `ConnectDiscoveryViewModel` (deck / pass / like)  
- `ConnectionInboxViewModel` (incoming / liked you)  
- `MatchesViewModel` (matches + open chat)  
Share small helpers if needed; inject only the repos each needs.

**Option B (smaller diff):**  
Keep one facade VM for coordinator wiring, but move load/enrichment into focused collaborators / use-case-like types used only by Connect (not a global Clean Architecture rollout).

Do **not** introduce TCA.

## Scope

1. Map current responsibilities → target types.
2. Update Views to take the right VM(s) with minimal UI churn.
3. Update `AppDependencies` / `AppCoordinator` / `MainTabView` wiring.
4. Migrate/split tests accordingly.
5. Improve cancellation where you touch load paths (owned `Task`, cancel on re-load / disappear) — but don’t boil the ocean.

## Out of scope

- Full UseCase layer for the whole app (Phase 7 can add 1–2 Connect use cases later)
- Chat repository split (Phase 4)
- Redesign of Connect UI/branding
- Commit / push / PR unless user asks

## Process

1. First message: architecture proposal (boundaries, ownership, data flow, DI) — wait for approval if multiple options conflict; otherwise pick Option A unless Views make it painful.
2. Branch: `phase-5-split-connect-viewmodel`.
3. Implement incrementally; keep app navigable.
4. Review: SOLID, race conditions, weak self / MainActor, testability.

## Acceptance criteria

- [ ] No single Connect VM owns all unrelated screen states
- [ ] Each new type has a clear owner and lifecycle
- [ ] Open-chat callback / navigation still works
- [ ] Tests updated and passing for Connect behaviors
- [ ] Build passes

## Example data flow (matches)

User opens Matches → MatchesView → MatchesViewModel → ConnectionRepository + UserRepository (+ ChatRepository on open) → state → UI → onOpenChat → AppCoordinator
