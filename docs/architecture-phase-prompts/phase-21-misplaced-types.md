# Phase 21 — Move misplaced types (AppleSignInPresenter, DirectChatPeer)

You are a senior iOS engineer working in the CircleLink repo.

## Goal

Relocate two misplaced types to clearer folders. No behavior change.

## Why

1. `AppleSignInPresenter` lives under `Data/Firebase/` but is UIKit AuthenticationServices presentation — not Firestore/Firebase data access.
2. `DirectChatPeer` lives under `Shared/` but encodes chat-id peer parsing for direct chats — chat/domain routing helper, not a generic shared util.

## Context

- `Data/Firebase/AppleSignInPresenter.swift`
- `Shared/DirectChatPeer.swift`
- Usages: `FirebaseAuthRepository`, `AppDependencies.makeChatViewModel`, possibly tests
- Docs: optional one-line structure note in `ARCHITECTURE.md`

## Scope

1. Move `AppleSignInPresenter` to a better home (suggestions: `Data/Auth/` or `App/Auth/`). Update Xcode project membership if needed.
2. Move `DirectChatPeer` near Chat/Domain (suggestions: `Chat/DirectChatPeer.swift` or `Domain/` if pure Foundation parsing with no UI). Prefer Domain only if it’s pure and reusable; otherwise Chat is fine.
3. Fix imports/targets; no API renames required unless clarity needs a rename (avoid rename churn).

## Out of scope

- ImageCompressor move (phase 9)
- CommunityPostItem (phase 8)
- Rewriting Apple Sign In
- Commit / push / PR unless user asks

## Process

1. Branch: `phase-21-misplaced-types`.
2. Move files + ensure Xcode includes them (this repo may use folder sync — verify build).
3. Build.

## Acceptance criteria

- [ ] Types no longer in misleading folders
- [ ] Behavior unchanged
- [ ] Build passes
