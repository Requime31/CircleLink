import Combine
import Foundation

/// One entry per post and authenticated account. All visible copies share pending state.
@MainActor
final class PostLikeStore: ObservableObject {
    struct Key: Hashable { let post: PostReference; let userId: String }
    struct State {
        var snapshot = PostLikeSnapshot()
        var pending: Bool?
        var pendingCount: Int?
        var countRevision = 0
        var likeRevision = 0
        var countReady = false
        var likeReady = false
        var ready: Bool { countReady && likeReady }
        var error: String?
        var isLiked: Bool { pending ?? snapshot.isLiked }
        var count: Int { pendingCount ?? snapshot.count }
    }
    @Published private(set) var states: [Key: State] = [:]
    private let service: PostLikeService
    private var observers: [Key: Task<Void, Never>] = [:]
    private var references: [Key: Int] = [:]

    init(service: PostLikeService) { self.service = service }
    func state(_ key: Key) -> State { states[key] ?? State() }

    func retain(_ key: Key) {
        references[key, default: 0] += 1
        guard observers[key] == nil else { return }
        if states[key] == nil { states[key] = State() }
        observers[key] = Task { [weak self, service] in
            guard let self else { return }
            async let count: Void = self.consumeCount(service.observeCount(post: key.post), key: key)
            async let liked: Void = self.consumeLike(service.observeLike(post: key.post, userId: key.userId), key: key)
            _ = await (count, liked)
        }
    }
    func retryObservation(_ key: Key) {
        guard states[key]?.pending == nil, let count = references[key], count > 0 else { return }
        observers.removeValue(forKey: key)?.cancel()
        states[key] = nil
        references[key] = count - 1
        retain(key)
    }
    func release(_ key: Key) {
        references[key, default: 1] -= 1
        guard references[key, default: 0] <= 0 else { return }
        observers.removeValue(forKey: key)?.cancel()
        references.removeValue(forKey: key)
        if states[key]?.pending == nil { states.removeValue(forKey: key) }
    }
    private func consumeCount(_ stream: AsyncThrowingStream<Int?, Error>, key: Key) async {
        do {
            for try await count in stream {
                guard !Task.isCancelled else { return }
                states[key, default: State()].countRevision += 1
                states[key, default: State()].snapshot.count = count ?? 0
                states[key, default: State()].countReady = true
                states[key, default: State()].snapshot.exists = count != nil
            }
        } catch { failObservation(key) }
    }
    private func consumeLike(_ stream: AsyncThrowingStream<Bool, Error>, key: Key) async {
        do {
            for try await liked in stream {
                guard !Task.isCancelled else { return }
                states[key, default: State()].likeRevision += 1
                states[key, default: State()].snapshot.isLiked = liked
                states[key, default: State()].likeReady = true
            }
        } catch { failObservation(key) }
    }
    private func failObservation(_ key: Key) {
        guard !Task.isCancelled else { return }
        states[key, default: State()].likeReady = false
        states[key, default: State()].error = "Likes are unavailable. Please try again."
    }
    func toggle(_ key: Key) async {
        let previous = state(key)
        guard previous.ready, previous.snapshot.exists, previous.pending == nil else { return }
        let desired = !previous.isLiked
        states[key]?.pending = desired
        states[key]?.pendingCount = max(0, previous.count + (desired ? 1 : -1))
        states[key]?.error = nil
        do {
            let committed = try await service.setLiked(desired, post: key.post, userId: key.userId)
            // Never overwrite a newer remote count, unlike, or deletion with an older
            // transaction completion. Pending presentation remains stable until this point.
            if state(key).countRevision == previous.countRevision {
                states[key]?.snapshot.count = committed.count
            }
            if state(key).likeRevision == previous.likeRevision {
                states[key]?.snapshot.isLiked = committed.isLiked
            }
        } catch {
            states[key]?.error = "Couldn’t update your like. Please try again."
        }
        states[key]?.pending = nil
        states[key]?.pendingCount = nil
        if references[key] == nil { states.removeValue(forKey: key) }
    }
}
