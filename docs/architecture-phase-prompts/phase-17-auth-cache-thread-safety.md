# Phase 17 — FirebaseAuthRepository cache thread safety

You are a senior iOS engineer working in the CircleLink repo.

## Goal

Fix unsafe mutable `cachedUser` behind `@unchecked Sendable` in `FirebaseAuthRepository`. Small, focused Data-layer change.

## Why

```swift
final class FirebaseAuthRepository: AuthRepository, @unchecked Sendable {
    private var cachedUser: User?
```

`@unchecked Sendable` silences the compiler; concurrent reads/writes of `cachedUser` are a data race risk under Swift concurrency.

## Context

- `Data/Firebase/FirebaseAuthRepository.swift`
- Protocol: `Domain/Repositories/AuthRepository.swift`
- Callers on MainActor (App/ViewModels) — verify actual call patterns before choosing a fix
- Related: phase 1 may have added `restoreSessionProfile()` — integrate, don’t break it

## Recommended options (pick simplest that is correct)

**A.** Make the repository `@MainActor` if all call sites are main-actor (common for this app).  
**B.** Protect cache with a lock / `OSAllocatedUnfairLock` / actor-isolated cache.  
**C.** Remove cache if it doesn’t buy much; always read from Firebase Auth + profile.

Explain WHY you chose A/B/C.

## Scope

1. Eliminate data race on `cachedUser` (or remove it).
2. Keep sign-in / sign-out / restore behavior.
3. Update stubs only if protocol/isolation changes force it.
4. Add a short comment why the chosen isolation is safe.

## Out of scope

- Apple Sign In UI rewrite
- Moving `AppleSignInPresenter` (phase 21)
- All other repositories’ `@unchecked Sendable` audit (mention leftovers only)
- Commit / push / PR unless user asks

## Process

1. Branch: `phase-17-auth-cache-thread-safety`.
2. Trace read/write sites of `cachedUser`.
3. Implement → build → run Auth-related tests.

## Acceptance criteria

- [ ] No unprotected mutable cache across concurrency domains
- [ ] Auth flows still work
- [ ] Prefer removing `@unchecked Sendable` if no longer needed; if kept, justify remaining reasons
- [ ] Build passes
