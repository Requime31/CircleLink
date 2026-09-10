import Foundation

/// Preview/test implementation. Domain repositories never instantiate Firebase.
@MainActor
final class StubPostLikeService: PostLikeService {
    var liked: [PostReference: Set<String>] = [:]
    var failure: Error?
    var suspended: CheckedContinuation<Void, Never>?
    var shouldSuspend = false
    private(set) var requests = 0
    private var countObservers: [PostReference: [UUID: AsyncThrowingStream<Int?, Error>.Continuation]] = [:]
    private var likeObservers: [PostLikeStore.Key: [UUID: AsyncThrowingStream<Bool, Error>.Continuation]] = [:]

    func setLiked(_ desired: Bool, post: PostReference, userId: String) async throws -> PostLikeSnapshot {
        requests += 1
        if shouldSuspend { await withCheckedContinuation { suspended = $0 } }
        if let failure { throw failure }
        if desired { liked[post, default: []].insert(userId) }
        else { liked[post, default: []].remove(userId) }
        publish(post)
        return PostLikeSnapshot(count: liked[post, default: []].count, isLiked: desired)
    }
    func publish(_ post: PostReference) {
        for continuation in countObservers[post, default: [:]].values { continuation.yield(liked[post, default: []].count) }
        for (key, observers) in likeObservers where key.post == post {
            for continuation in observers.values { continuation.yield(liked[post, default: []].contains(key.userId)) }
        }
    }
    func observeCount(post: PostReference) -> AsyncThrowingStream<Int?, Error> {
        AsyncThrowingStream { continuation in
            let id = UUID()
            countObservers[post, default: [:]][id] = continuation
            continuation.yield(liked[post, default: []].count)
            continuation.onTermination = { [weak self] _ in Task { @MainActor [weak self] in self?.countObservers[post]?[id] = nil } }
        }
    }
    func observeLike(post: PostReference, userId: String) -> AsyncThrowingStream<Bool, Error> {
        AsyncThrowingStream { continuation in
            let key = PostLikeStore.Key(post: post, userId: userId), id = UUID()
            likeObservers[key, default: [:]][id] = continuation
            continuation.yield(liked[post, default: []].contains(userId))
            continuation.onTermination = { [weak self] _ in Task { @MainActor [weak self] in self?.likeObservers[key]?[id] = nil } }
        }
    }
    func canNavigate(userId: String, viewerId: String) async throws -> Bool { true }
    func likerIds(post: PostReference, after: String?, limit: Int) async throws -> [String] {
        Array(liked[post, default: []].sorted().filter { after == nil || $0 > after! }.prefix(max(1, limit)))
    }
}
