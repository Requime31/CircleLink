# Phase 2 — Connect: batch profile loading (kill N+1)

You are a senior iOS engineer working in the CircleLink repo.

## Goal

Stop serial one-by-one `fetchProfile` loops in Connect. Use the existing `UserRepository.fetchProfiles(userIds:)` batch API.

## Why

`ConnectViewModel` loads matches / related peers with a loop like:

```swift
for request in requests {
    let peer = try await userRepository.fetchProfile(userId: peerId)
    ...
}
```

`UserRepository` already has `fetchProfiles(userIds:)`, and Community Feed already uses it. Serial N+1 is slow and duplicates a solved pattern.

## Context

- Target: `CircleLink/Features/Connect/ConnectViewModel.swift` (methods that enrich requests with peers — around matches / incoming)
- Batch API: `CircleLink/Domain/Repositories/UserRepository.swift`
- Good reference: `CircleLink/Features/Communities/CommunityFeedViewModel.swift` (author enrichment)
- Live impl: `CircleLink/Data/Firebase/FirestoreUserRepository.swift`
- Tests: `CircleLinkTests/ConnectViewModelTests.swift`
- Docs: `ARCHITECTURE.md`

## Scope (do only this)

1. Find all serial `fetchProfile` loops in Connect that can batch.
2. Collect unique peer IDs → call `fetchProfiles` once (or few chunks if needed).
3. Map results back to UI items; keep blocked-user filtering behavior.
4. Preserve error semantics as much as possible (don’t silently turn hard failures into empty lists unless that was already the contract — document if you must change).
5. Update Connect ViewModel tests for the batch path.

## Out of scope

- Splitting `ConnectViewModel` into multiple VMs (Phase 5)
- Adding UseCases (Phase 7)
- Changing FirestoreConnectionRepository candidate fetching (unless required for compile/consistency)
- UI redesign of Connect screens
- Commit / push / PR unless user asks

## Process

1. List exact call sites with line references before coding.
2. Create branch: `phase-2-connect-batch-profiles`.
3. Implement minimal change → build → run `ConnectViewModelTests`.
4. Mentorship note: explain why batching belongs in VM orchestration (or why not elevating to repo yet).

## Acceptance criteria

- [ ] No serial N+1 peer profile fetch in Connect match/enrich paths
- [ ] Uses `fetchProfiles(userIds:)`
- [ ] Blocked users still filtered
- [ ] Tests cover success with multiple peers
- [ ] Build passes

## Data flow after change

User opens Connect → View → `ConnectViewModel.load…` → `ConnectionRepository` (requests) → collect peerIds → `UserRepository.fetchProfiles` → map to items → `@Published` state → UI
