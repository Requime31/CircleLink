---
id: adr-backend-unified-post-like-model
title: Unified Post-Like Model
type: decision
status: implemented
date: 2026-09-10
tags: [backend, firestore, likes, notifications]
sources:
  - git:6340b52
  - legacy:docs/POST_LIKES.md
---

# Unified Post-Like Model

## Context

Community and profile posts need consistent like state, counts, navigation, and notifications.
Arrays of liker IDs would create contention, access, and growth problems.

## Decision

Both post types use deterministic `likes/{userId}` membership documents and an atomic parent
`likeCount`. One `PostLikeStore` coordinates optimistic state across screens. Firestore rules
validate exact transitions. Server-owned activity documents and Firebase Functions deduplicate,
aggregate, revalidate, and attempt FCM delivery.

Notifications favor an at-most-once claimed attempt over automatic resend after ambiguous failure.
Legacy missing counts initialize safely, and a dry-run-first migration can backfill consistent data.

## Consequences

The model is idempotent and consistent across surfaces. The single count remains a serialization
point at very high traffic, and at-most-once claiming can lose an ambiguous push rather than send a
duplicate.

## Sources

- [Unified post likes](../../backend/post-likes.md)
- Stable implementation commit `6340b52`.
- `CircleLink/Data/Firebase/FirestorePostLikeService.swift` and `functions/activity.js`.
