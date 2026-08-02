# Phase 8 — Domain cleanup: move CommunityPostItem to presentation

You are a senior iOS engineer working in the CircleLink repo.

## Goal

Move `CommunityPostItem` out of Domain. Keep Domain models as business entities; feed-row composition belongs to Communities presentation (or a feature-local view-data type).

## Why

In `Domain/Models/CommunityPost.swift`:

```swift
/// Feed row: post + resolved author profile
struct CommunityPostItem ...
```

This is view/feed composition, not a core domain entity. It weakens Domain purity even though imports are still only Foundation.

## Context

- Definition: `CircleLink/Domain/Models/CommunityPost.swift`
- Likely users: `CommunityFeedViewModel`, feed views/cards, tests, maybe repository return types
- Docs: `ARCHITECTURE.md` (Domain stays pure)

## Scope

1. Find all references to `CommunityPostItem`.
2. Move type to Features/Communities (e.g. `CommunityPostItem.swift` or inside feed view-data file).
3. Ensure Domain `CommunityPost` stays; repositories should return posts/authors separately or Domain-neutral DTOs — **do not** pull SwiftUI into Domain.
4. If a repository currently returns `CommunityPostItem`, change it to return domain-friendly data and map in the ViewModel (preferred).
5. Update tests/imports.
6. Optional small cleanup in the same PR only if directly related: comments that describe Firestore paths can stay; don’t expand scope to `avatarBase64` unless trivial and requested.

## Out of scope

- Redesigning the feed UI
- Image pipeline
- Broader Domain model redesign (`User.avatarBase64`, `OrganizedChats`) — mention as follow-ups only
- Commit / push / PR unless user asks

## Process

1. Grep usages; propose target file path.
2. Branch: `phase-8-domain-community-post-item`.
3. Move + fix compile + run Communities/Feed-related tests.

## Acceptance criteria

- [ ] `CommunityPostItem` no longer lives under `Domain/`
- [ ] Domain still imports only Foundation
- [ ] Feed still shows post + author
- [ ] Build + relevant tests pass

## Data flow after change

Feed load → CommunityFeedViewModel → CommunityPostRepository + UserRepository → map to feature `CommunityPostItem` → View
