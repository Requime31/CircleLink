import Foundation
import Testing
@testable import CircleLink

@MainActor
struct PostLikeStoreTests {
    private func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(3)
        while !condition() && ContinuousClock.now < deadline { await Task.yield() }
        try #require(condition())
    }
    @Test(arguments: [PostReference.Kind.community, .profile])
    func likeUnlikeAndIdempotency(kind: PostReference.Kind) async throws {
        let service = StubPostLikeService()
        let post = PostReference(kind: kind, ownerId: "owner", postId: "post")
        _ = try await service.setLiked(true, post: post, userId: "me")
        let duplicate = try await service.setLiked(true, post: post, userId: "me")
        #expect(duplicate.count == 1)
        _ = try await service.setLiked(false, post: post, userId: "me")
        let removed = try await service.setLiked(false, post: post, userId: "me")
        #expect(removed == PostLikeSnapshot(count: 0, isLiked: false))
    }
    @Test(arguments: [PostReference.Kind.community, .profile])
    func optimisticRollbackAndSharedPendingState(kind: PostReference.Kind) async throws {
        let service = StubPostLikeService()
        let store = PostLikeStore(service: service)
        let key = PostLikeStore.Key(post: .init(kind: kind, ownerId: "owner", postId: "post"), userId: "me")
        store.retain(key)
        store.retain(key)
        defer { store.release(key); store.release(key) }
        try await waitUntil { store.state(key).ready }
        service.shouldSuspend = true
        service.failure = NSError(domain: "test", code: 1)
        let request = Task { await store.toggle(key) }
        try await waitUntil { service.suspended != nil }
        #expect(store.state(key).isLiked)
        #expect(store.state(key).count == 1)
        await store.toggle(key)
        #expect(service.requests == 1)
        // A remote like during our failed transaction must survive rollback.
        service.liked[key.post] = ["peer"]
        service.publish(key.post)
        try await waitUntil { store.state(key).snapshot.count == 1 }
        service.suspended?.resume()
        await request.value
        #expect(!store.state(key).isLiked)
        #expect(store.state(key).count == 1)
        #expect(store.state(key).error != nil)
        #expect(store.state(key).pending == nil)
    }
    @Test func realtimeAndReferenceLifetime() async throws {
        let service = StubPostLikeService()
        let store = PostLikeStore(service: service)
        let key = PostLikeStore.Key(post: .init(kind: .profile, ownerId: "owner", postId: "post"), userId: "me")
        store.retain(key); store.retain(key)
        try await waitUntil { store.state(key).ready }
        store.release(key)
        service.liked[key.post] = ["me", "peer"]
        service.publish(key.post)
        try await waitUntil { store.state(key).count == 2 && store.state(key).isLiked }
        await store.toggle(key)
        #expect(store.state(key).count == 1)
        #expect(!store.state(key).isLiked)
        store.release(key)
        #expect(store.states[key] == nil)
    }
    @Test func postPushRequiresValidSpecificPostAndRecipient() {
        let valid: [AnyHashable: Any] = ["type":"post_activity", "postKind":"community", "ownerId":"group", "postId":"post", "targetUserId":"owner"]
        #expect(PushDeepLink.parse(userInfo: valid)?.post == PostReference(kind: .community, ownerId: "group", postId: "post"))
        var invalid = valid
        invalid["postId"] = "other/path"
        #expect(PushDeepLink.parse(userInfo: invalid) == nil)
        invalid = valid; invalid["targetUserId"] = nil
        #expect(PushDeepLink.parse(userInfo: invalid) == nil)
    }
    @Test func pendingRequestSurvivesLastCardDisappearingAndReturning() async throws {
        let service = StubPostLikeService()
        let store = PostLikeStore(service: service)
        let key = PostLikeStore.Key(post: .init(kind: .community, ownerId: "owner", postId: "post"), userId: "me")
        store.retain(key)
        try await waitUntil { store.state(key).ready }
        service.shouldSuspend = true
        let request = Task { await store.toggle(key) }
        try await waitUntil { service.suspended != nil }
        store.release(key)
        store.retain(key)
        #expect(store.state(key).pending == true)
        await store.toggle(key)
        #expect(service.requests == 1)
        service.suspended?.resume()
        await request.value
        try await waitUntil { store.state(key).isLiked && store.state(key).count == 1 }
        store.release(key)
    }
    @Test func legacyCodablePostsDefaultCountToZero() throws {
        let profile = Data(#"{"id":"p","authorId":"a","text":"Hello","createdAt":0}"#.utf8)
        let community = Data(#"{"id":"p","communityId":"c","authorId":"a","text":"Hello","createdAt":0}"#.utf8)
        #expect(try JSONDecoder().decode(ProfilePost.self, from: profile).likeCount == 0)
        #expect(try JSONDecoder().decode(CommunityPost.self, from: community).likeCount == 0)
    }

}
