# Phase 7 — Targeted UseCases (only multi-repository workflows)

You are a senior iOS engineer working in the CircleLink repo.

## Goal

Add a **small** UseCase layer only for workflows that already orchestrate multiple repositories or have non-trivial ordering rules. Do not create UseCases for simple CRUD.

## Why

ARCHITECTURE.md says “No UseCase layer in MVP — ViewModel calls Repository directly.” That still fits most screens. Exceptions that hurt today:

1. **Confirm age** — `UserRepository.confirmAge` + fetch profile + session check (`AgeGateViewModel`)
2. **Leave community** — leave group chat **then** leave community (`CommunityDetailViewModel`)
3. **Open community chat** — members fetch, derive participants, create/open group chat

These belong in named application services so ViewModels stay presentation-focused and rules aren’t duplicated.

## Context

- Age gate: `Features/AgeGate/AgeGateViewModel.swift`
- Community detail: `Features/Communities/CommunityDetailViewModel.swift` (and related)
- Repos: `AuthRepository`, `UserRepository`, `CommunityRepository`, `ChatRepository`
- DI: `AppDependencies.swift`
- Docs: `ARCHITECTURE.md` — update the “No UseCase” note to “UseCases only for multi-repo workflows”

## Scope

1. Create a clear folder, e.g. `CircleLink/Domain/UseCases/` or `CircleLink/Application/UseCases/` — pick one, explain WHY.
2. Implement only these (names flexible):
   - `ConfirmAgeUseCase`
   - `LeaveCommunityUseCase`
   - `OpenCommunityChatUseCase` (or equivalent)
3. Inject use cases into the affected ViewModels via `AppDependencies` factories.
4. Move ordering / guard rules into use cases; VM keeps `ViewState` / UI flags.
5. Update existing AgeGate / CommunityDetail tests to use use case mocks or fake collaborators.

## Out of scope

- UseCase for every repository method
- Rewriting Connect entirely (Phase 5) — optional tiny Connect use case only if it clearly helps and stays in scope; default = skip Connect here
- UI redesign
- Commit / push / PR unless user asks

## Design constraints

- Prefer struct + protocol only if you need mocking; don’t invent generic `UseCase<Input, Output>` frameworks.
- Keep Domain free of Firebase/UIKit/SwiftUI.
- Preserve leave-chat-before-leave-community order (security/rules comment in code).

## Process

1. Propose file layout + signatures first.
2. Branch: `phase-7-targeted-usecases`.
3. Implement one use case at a time; keep build green.
4. Update ARCHITECTURE.md briefly (one short section).

## Acceptance criteria

- [ ] Exactly the multi-repo flows above use UseCases (not a blanket layer)
- [ ] ViewModels no longer contain the critical ordering business rules for those flows
- [ ] Tests updated
- [ ] ARCHITECTURE.md reflects the new rule
- [ ] Build passes

## Data flow example (leave community)

User taps Leave → CommunityDetailView → ViewModel → `LeaveCommunityUseCase` → ChatRepository.leaveGroupChat → CommunityRepository.leave → result → ViewModel state → UI
