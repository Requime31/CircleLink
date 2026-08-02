# Phase 1 — Auth session restore on the protocol

You are a senior iOS engineer working in the CircleLink repo.

## Goal

Remove the concrete Firebase downcast in the composition root by putting session restore on the `AuthRepository` protocol.

## Why

`AppDependencies.restoreAuthenticatedProfile()` currently does:

```swift
if let firebaseAuth = authRepository as? FirebaseAuthRepository {
    return try await firebaseAuth.restoreSessionProfile()
}
```

Mocks and alternate auth implementations cannot provide the same behavior. Domain contract must own this capability.

## Context

- Architecture: View → ViewModel → Repository protocol ← Data
- Composition root: `CircleLink/App/AppDependencies.swift`
- Protocol: `CircleLink/Domain/Repositories/AuthRepository.swift`
- Live: `CircleLink/Data/Firebase/FirebaseAuthRepository.swift`
- Stubs/mocks: `CircleLink/Data/Stubs/StubAuthRepository.swift`, `CircleLinkTests/Mocks/`
- Docs: `ARCHITECTURE.md`

## Scope (do only this)

1. Add something like `func restoreSessionProfile() async throws -> User?` to `AuthRepository`.
2. Keep / wire the existing Firebase implementation to that protocol method.
3. Update stubs + test mocks.
4. Change `AppDependencies.restoreAuthenticatedProfile()` to call the protocol — **no** `as? FirebaseAuthRepository`.
5. Update/add tests if restore behavior is covered or easily coverable.

## Out of scope

- Push notifications
- Connect / Chat refactors
- New UseCase layer
- Changing sign-in / sign-up APIs beyond what’s needed
- Commit / push / PR unless user asks

## Process

1. Analyze current `restoreSessionProfile` behavior first; propose the exact protocol signature.
2. Wait for approval only if the signature is ambiguous; otherwise implement in a small increment.
3. Create branch: `phase-1-auth-session-restore`.
4. Implement → build → run relevant tests.
5. Short review: architecture, thread safety, edge cases (nil session, expired session, stub path).

## Acceptance criteria

- [ ] No Firebase concrete cast in `AppDependencies` for restore
- [ ] Stub/mock auth can restore (or return nil) via the same API
- [ ] Existing auth/age-gate/bootstrap flow still works
- [ ] `xcodebuild` / tests for touched area pass

## Data flow after change

App launch → `AppCoordinator.bootstrapIfNeeded` → `AppDependencies.restoreAuthenticatedProfile` → `AuthRepository.restoreSessionProfile` → Firebase Auth + profile fetch (Data) → `User?` → coordinator chooses route
