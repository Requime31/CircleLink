# Unified post likes

Both CommunityPostCard and ProfilePostsListView (including peer profiles and the push post-detail screen) use PostLikeBar and one session-scoped PostLikeStore. Shared/PostCardView does not exist in this checkout. There is one Like action, no reaction picker.

## Firestore schema

For either parent:

- `communities/{communityId}/posts/{postId}`
- `users/{authorId}/profilePosts/{postId}`

The post contains `likeCount: Int`, initially zero. It never contains an array of liker IDs.

Subcollections:

- `likes/{userId}`: `{ createdAt: serverTimestamp }`. Existence is the desired boolean state; the document ID enforces one like per account.
- `activity/{actorId}`: server-only durable event/outbox/receipt with `type`, `actorId`, `targetUserId`, `postPath`, `aggregationKey`, `actorCount`, `windowId`, `createdAt`, and delivery `status`. Optional `claimedAt` and `failureCode` record delivery outcomes.
- `activitySummary/recent`: server-only bounded summary `{ windowId, actorCount, latestActorId, updatedAt }` for a five-minute activity window. No growing actor arrays.

`users/{peerId}/profileAccess/{viewerId}` is a read-only authorization probe, not stored data. A successful missing-document get means both accounts are active and neither has blocked the other. This protects navigation without exposing another user's block list.

The count represents existing like documents, including historical likes from accounts that later become unavailable. The list excludes unavailable accounts. Therefore the total may exceed the number of navigable profiles; this is deliberate. Profile availability is checked again on selection.

## Atomicity, retries, and realtime

FirestorePostLikeService is shared by both Firestore repositories through AppDependencies. `setLiked(desiredState)` reads the parent and deterministic like document in a transaction, returns without writing if the desired state already exists, and otherwise creates/deletes the like with an atomic count increment/decrement in the same commit.

Rules independently validate the transition. A stale concurrent transaction can surface as PERMISSION_DENIED before Firestore's normal ABORTED retry. The service allows at most three additional fresh-transaction attempts with short increasing delays. Permanent permission errors still fail and roll back. No transaction callback sends push or performs unrelated side effects.

The single count document is a serialization point under extremely high traffic. Transactions preserve correctness and surface exhausted contention to the UI; they do not silently lose increments. A future sharded counter requires a coordinated rules/client migration, not simply replacing the count update.

PostLikeStore keys include post kind, owner, post ID, and current account. All cards share one pending flag, optimistic count, and server snapshot. Rapid taps cannot start another operation. Listener subscriptions are reference-counted; pending state survives disappearance/reappearance. Errors remove the optimistic overlay while preserving remote updates. Revision checks prevent an older completion from overwriting newer observed state. Both document listeners include metadata changes and ignore unacknowledged local writes.

The liker list paginates by document ID, 50 entries per page. It observes loaded user profiles and revalidates active/block state before navigation. English labels, semantic text fonts, wrapping names, VoiceOver labels/values, and minimum 44-point controls are provided.

## Rules

- Signed-in, active actor and author, no block in either direction.
- Community writes additionally require community membership.
- Like create/delete is restricted to the authenticated account's document.
- Like fields are limited to server `createdAt`; updates are forbidden.
- Like writes require an existing parent after the commit and exactly the matching count delta.
- Count-only updates require the corresponding like existence transition. Counts must be nonnegative integers.
- Ordinary post editing preserves the count. Post creation accepts only zero or the legacy absent field.
- Clients cannot create activity events, delivery statuses, or summaries.
- All like/activity reads depend on parent existence; deleting a post immediately makes orphaned subcollections inaccessible. Notification processing rechecks parent existence. Physical recursive cleanup is optional; no client enumeration/delete loop is required.
- Post IDs must not be reused after deletion. Standard compose flows generate new IDs.

## Indexes

The liker list uses Firestore's built-in document-ID ordering, so no composite likes index is required. The unused `likes.createdAt` index is disabled to reduce write amplification. An `activity.status` ascending collection-group index supports server outbox inspection/processing. Existing application indexes are preserved.

## Notifications

Cloud Functions record a new activity event and update the five-minute aggregation summary transactionally. A durable receipt is keyed by post + actor, so trigger retries and unlike/re-like do not create another event or push for that actor on that post, even across aggregation windows. Self-likes affect the count but create no self-notification. Unlike has no notification trigger.

Messages support `Anna liked your post.`, `Anna and 1 other liked your post.`, and `Anna and 4 others liked your post.` Counts describe distinct recorded activity in the window, not a fresh aggregation of currently navigable likers. APNs collapse IDs group notifications for the same post. Each event checks the current like, parent, both account states, blocks, and recipient token again before delivery.

A transaction claims delivery before contacting FCM, providing an at-most-once send attempt. FCM has no transactional idempotency key: a crash after claiming or an ambiguous send failure can lose that push. The durable activity remains available, and failed sends are recorded; automatic resend is intentionally avoided to prevent duplicate alerts. This is not an exactly-once delivery guarantee.

Payload: `type=post_activity`, `targetUserId`, `postKind=community|profile`, `ownerId`, `postId`, `aggregationKey`. The parser rejects malformed IDs and missing recipients. AppCoordinator opens the exact post, validates the signed-in recipient, and shows an unavailable state for a missing/inaccessible post.

## Safe migration and rollout

Existing posts read as zero when `likeCount` is absent, both in Firestore mappers and Codable decoding. New posts explicitly write zero. The first like on a legacy post initializes the count atomically.

`functions/scripts/migrate-like-counts.js` optionally backfills old posts in pages of 200. It runs in dry-run mode by default. Each post is re-read in a transaction; initialized counts are never overwritten. Missing parents are skipped. Unexpected existing likes with no count stop migration for manual reconciliation rather than inventing a zero count. The migration is repeatable and safe alongside normal client like transactions.

Recommended rollout:

1. Install locked dependencies: `npm ci --prefix functions`.
2. Deploy Firestore rules/indexes and the `post-activity` Functions codebase to the intended project.
3. Using approved ADC credentials, run `GCLOUD_PROJECT=<project> node functions/scripts/migrate-like-counts.js` to review the dry run.
4. Apply with `GCLOUD_PROJECT=<project> node functions/scripts/migrate-like-counts.js --apply`.
5. Release the app and smoke-test real APNs/FCM delivery on a device.

No production deployment, production data migration, or real push send was performed during implementation. Emulator fixtures exercised the migration with concurrent writes.

## Validation

- Xcode build and full Swift Testing suite on iPhone 14 / iOS 18.5 simulator.
- Firestore Emulator: `firebase emulators:exec --only firestore --project demo-circlelink-likes 'npm --prefix functions test'`.
- Emulator tests cover both post types, create/delete, idempotency, concurrent same/different users, count forgery, isolated like writes, unauthenticated access, non-members, deleted parent/user, deactivation, both blocking directions, navigation probes, event forgery, notification deduplication, self-like, suppression before delivery, aggregation messages, migration dry-run/retries/concurrent writes/inconsistent legacy data.
- Swift tests cover optimistic rollback with concurrent remote changes, duplicate taps, shared observer lifetime, disappearance/reappearance while pending, legacy decoding, and notification payload validation.

Manual VoiceOver/Dynamic Type interaction and real device push delivery still need a release smoke test; the simulator/unit tests do not validate spoken output or APNs delivery.

## Changed files

App composition/navigation: `App/AppDependencies.swift`, `App/AppCoordinator.swift`, `App/PushDeepLink.swift`.

Domain: `Domain/Models/CommunityPost.swift`, `ProfilePost.swift`, `PostReference.swift`; `Domain/Repositories/CommunityPostRepository.swift`, `ProfilePostRepository.swift`.

Data: `Data/Firebase/FirestorePostLikeService.swift`, `FirestorePostActivityRepository.swift`, both post repositories and mappers; `Data/Stubs/StubPostLikeService.swift`, both stub post repositories.

UI: `Shared/Likes/PostLikeStore.swift`, `PostLikeBar.swift`, `PostActivityDetailView.swift`; `Features/Communities/CommunityPostCard.swift`, `Features/Profile/ProfilePostsListView.swift`; `Shared/Guides/CLGuideModels.swift`.

Tests: `CircleLinkTests/PostLikeStoreTests.swift`, `CommunityDetailViewModelTests.swift`, `Mocks/MockRepositories.swift`; `functions/test/likes.test.js`.

Backend/configuration: `functions/activity.js`, `functions/index.js`, `functions/package.json`, `functions/package-lock.json`, `functions/scripts/migrate-like-counts.js`, `firestore.rules`, `firestore.indexes.json`, `firebase.json`, `.gitignore`, this document.

Reference contracts: [Firestore transaction validation](https://firebase.google.com/docs/firestore/security/rules-conditions), [at-least-once Firestore trigger delivery](https://firebase.google.com/docs/functions/firestore-events).
