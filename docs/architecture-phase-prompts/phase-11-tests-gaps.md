# Phase 11 — Fill ViewModel / helper test gaps (cancellation & missing suites)

You are a senior iOS engineer working in the CircleLink repo.

## Goal

Add high-value unit tests that the architecture audit found missing — especially cancellation/stale-response behavior and untested ViewModels/helpers. Prefer tests that lock architecture boundaries, not UI snapshots.

## Why

Existing suites cover Auth, AgeGate, Communities, CommunityDetail, Connect, Profile, Chat outcomes. Gaps:

- `PeerProfileViewModel`
- `CommunityFeedViewModel`
- `ChatsViewModel`
- `ChatInfoViewModel`
- `SettingsViewModel` (needs protocol from Phase 3 — skip or stub if Phase 3 not merged)
- cancellation / stale overwrite races
- pure helpers from Phase 6 (reconciler/mapper) if present
- optional: coordinator route helper from Phase 10 if extracted

## Context

- Tests folder: `CircleLinkTests/`
- Mocks: `CircleLinkTests/Mocks/MockRepositories.swift`
- Style: Swift Testing (see existing `*ViewModelTests.swift`)
- Skill/style: follow existing test patterns in the repo; no Firebase in unit tests
- Docs: `ARCHITECTURE.md`

## Scope (prioritize)

Do in this order unless a dependency is missing:

1. **CommunityFeedViewModel** — first page, empty, error, pagination basics, author batch enrichment
2. **ChatsViewModel** — load visible/hidden, search filter, optimistic mute/hide rollback if implemented
3. **PeerProfileViewModel** — load profile+connection, connect/remove acting flag
4. **ChatInfoViewModel** — load + leave
5. **Cancellation / stale** — at least one strong example (e.g. double load where second wins; or task cancel does not apply stale state) in a VM that already owns tasks
6. **SettingsViewModel** — only if notification settings protocol exists
7. Pure unit tests for any extracted chat reconciler/mapper

## Out of scope

- UIKit snapshot tests for MessageCell
- Live Firebase integration tests
- Rewriting production code except tiny test seams that are clearly justified (prefer using existing protocols)
- Commit / push / PR unless user asks

## Process

1. Inventory current tests vs targets; note blockers (e.g. Settings still concrete).
2. Branch: `phase-11-tests-gaps`.
3. Add tests in small PRs-worth chunks; keep them deterministic (no `sleep`; controllable mocks).
4. Run the full `CircleLinkTests` target.

## Acceptance criteria

- [ ] At least Feed + Chats + PeerProfile suites exist and pass
- [ ] At least one cancellation/stale race test exists
- [ ] Mocks stay free of Firebase
- [ ] CI/local test run green for CircleLinkTests

## Note for the agent

If earlier phases already added some of these tests, don’t duplicate — extend coverage where still thin. Explain simply what each new test protects.
