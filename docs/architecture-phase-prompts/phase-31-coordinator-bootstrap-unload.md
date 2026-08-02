# Phase 31 — Unload AppCoordinator bootstrap / session routing

You are a senior iOS engineer working in the CircleLink repo.

## Goal

Move session restore + “which onboarding route?” rules out of the fat `AppCoordinator`, so the coordinator mostly owns navigation state and screen assembly — not profile completeness business rules.

## Why

`AppCoordinator` (~306 LOC) mixes: root route, tab selection, deep links, retaining all tab VMs, building `MainTabView`, **and** bootstrap profile fetch / age / profile-setup decisions.

Phase 10 only removes ChatsViewModel state reads for deep links. This phase targets bootstrap/session routing.

## Context

- `App/AppCoordinator.swift` (`bootstrapIfNeeded`, `applyRoute(for:)`, auth handlers)
- `App/AppDependencies.swift` (`restoreAuthenticatedProfile`)
- Phase 1 should already put restore on `AuthRepository`
- Domain helpers: `User+Profile.swift` (completeness) — prefer pure functions here or a tiny session policy type

## Recommended approach

Extract something small like:

- `SessionBootstrapper` / `OnboardingRouteResolver`  
  Input: `User?` / restore result → Output: `AppCoordinator.Route` (or equivalent)

Coordinator calls it, then sets `route`. Keep it MainActor-simple; no new framework.

## Scope

1. Extract bootstrap + route decision logic from coordinator.
2. Keep UX identical: auth → age gate → profile setup → main tabs.
3. Coordinator still owns `@Published route` / tabs / pending chat.
4. Optional: thin tests for route resolver pure decisions (best ROI).

## Out of scope

- Tab routers / MainTabView relay (phase 32)
- Push handler split (phase 30)
- Rewriting all feature factories
- Commit / push / PR unless user asks

## Process

1. Branch: `phase-31-coordinator-bootstrap-unload`.
2. Propose resolver API → implement → build → Auth/AgeGate smoke checklist.

## Acceptance criteria

- [ ] Bootstrap/route policy not embedded as large private methods soup in coordinator (extracted type/functions)
- [ ] Same onboarding routing behavior
- [ ] Prefer unit tests for route decisions
- [ ] Build passes

## Data flow

Launch → Coordinator.bootstrap → SessionBootstrapper (restore via AuthRepository + optional profile fetch) → Route → rootView switch
