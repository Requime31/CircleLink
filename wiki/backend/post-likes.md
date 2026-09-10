---
title: Unified Post Likes
type: backend
status: current
updated: 2026-09-11
tags: [backend, firestore, likes, notifications]
---

# Unified Post Likes

Community and profile posts share one like model and session-scoped `PostLikeStore`. A parent post
stores `likeCount`; deterministic `likes/{userId}` documents store membership without liker arrays.
The client transaction creates or deletes the like and changes the count atomically.

Rules require active participants, no block in either direction, valid community membership where
applicable, the authenticated user's deterministic like document, and the exact matching count
delta. Legacy posts without a count read as zero and initialize on the first like.

Server-owned activity documents form a durable event and delivery record. Firebase Functions
aggregate distinct actors in a five-minute window and attempt FCM delivery after rechecking the
like, parent, account states, blocks, and recipient token. Delivery uses an at-most-once claim;
ambiguous infrastructure failure may lose a push rather than risk duplicates.

The liker list paginates by document ID. Counts include historical likes whose actors later become
unavailable, while navigation filters inaccessible profiles. High-volume counters may eventually
need sharding, which requires coordinated client and rules migration.

## Migration and validation

`functions/scripts/migrate-like-counts.js` is dry-run by default, re-reads each post in a
transaction, preserves initialized counts, and stops on inconsistent legacy data. Firestore
Emulator tests cover both post types, concurrency, rule rejection, activity, delivery suppression,
and migration behavior.

## Related decision

- [Unified post-like model](../decisions/backend/unified-post-like-model.md)

## Sources

- Legacy `docs/POST_LIKES.md`, migrated during bootstrap.
- `CircleLink/Shared/Likes/`.
- `CircleLink/Data/Firebase/FirestorePostLikeService.swift`.
- `functions/` and `functions/test/likes.test.js`.
