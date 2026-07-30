import Combine
import Foundation

@MainActor
final class CommunityFeedViewModel: ObservableObject {
    enum AccessState: Equatable {
        case unknown
        /// Signed-in but not a member — rules block feed reads.
        case joinRequired
        case member
    }

    @Published private(set) var accessState: AccessState = .unknown
    @Published private(set) var items: [CommunityPostItem] = []
    @Published private(set) var feedState: ViewState<[CommunityPostItem]> = .idle
    @Published private(set) var isLoadingMore = false
    @Published private(set) var canLoadMore = false
    @Published private(set) var isPosting = false
    @Published private(set) var deletingPostId: String?
    @Published var errorMessage: String?

    let communityId: String

    var currentUserId: String? { authRepository.currentUser?.id }

    private let pageSize = 20
    private let postRepository: CommunityPostRepository
    private let userRepository: UserRepository
    private let authRepository: AuthRepository

    private var authorCache: [String: User] = [:]
    private var loadTask: Task<Void, Never>?
    private var loadMoreTask: Task<Void, Never>?

    init(
        communityId: String,
        postRepository: CommunityPostRepository,
        userRepository: UserRepository,
        authRepository: AuthRepository
    ) {
        self.communityId = communityId
        self.postRepository = postRepository
        self.userRepository = userRepository
        self.authRepository = authRepository
    }

    /// Call when membership is known (from CommunityDetailViewModel).
    func syncMembership(isMember: Bool) {
        let next: AccessState = isMember ? .member : .joinRequired
        guard accessState != next else { return }
        accessState = next

        if isMember {
            reload()
        } else {
            cancelLoads()
            items = []
            feedState = .idle
            canLoadMore = false
            errorMessage = nil
        }
    }

    func reload() {
        guard accessState == .member else { return }
        cancelLoads()
        loadTask = Task { await loadFirstPage() }
    }

    func loadMoreIfNeeded(currentItem: CommunityPostItem) {
        guard accessState == .member,
              canLoadMore,
              !isLoadingMore,
              feedState.isLoadedOrEmpty,
              currentItem.id == items.last?.id
        else { return }

        loadMoreTask?.cancel()
        loadMoreTask = Task { await loadNextPage() }
    }

    /// Create post: text-only, photo-only, or both.
    func createPost(text: String?, imageData: Data?) async -> Bool {
        guard accessState == .member else {
            errorMessage = "Join this community to post."
            return false
        }

        guard !isPosting else { return false }

        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasText = !(trimmed?.isEmpty ?? true)
        let hasImage = imageData != nil

        guard hasText || hasImage else {
            errorMessage = "Add text or a photo to post."
            return false
        }

        isPosting = true
        errorMessage = nil
        defer { isPosting = false }

        do {
            let postId = UUID().uuidString
            let post = try await postRepository.createPost(
                communityId: communityId,
                postId: postId,
                text: hasText ? trimmed : nil,
                image: imageData
            )
            let item = CommunityPostItem(post: post, author: await author(for: post.authorId))
            items.insert(item, at: 0)
            feedState = items.isEmpty ? .empty : .loaded(items)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func deletePost(_ item: CommunityPostItem) async {
        guard item.post.authorId == currentUserId else { return }
        guard deletingPostId == nil else { return }

        deletingPostId = item.post.id
        errorMessage = nil
        defer { deletingPostId = nil }

        do {
            try await postRepository.deletePost(item.post)
            items.removeAll { $0.id == item.id }
            feedState = items.isEmpty ? .empty : .loaded(items)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearError() {
        errorMessage = nil
    }

    /// Cancel in-flight loads when leaving the community detail screen.
    func onDisappear() {
        cancelLoads()
    }

    // MARK: - Private

    private func loadFirstPage() async {
        feedState = .loading
        errorMessage = nil

        do {
            let posts = try await postRepository.fetchPosts(
                communityId: communityId,
                limit: pageSize,
                before: nil
            )
            guard !Task.isCancelled else { return }

            let pageItems = try await makeItems(from: posts)
            guard !Task.isCancelled else { return }

            items = pageItems
            canLoadMore = posts.count == pageSize
            feedState = pageItems.isEmpty ? .empty : .loaded(pageItems)
        } catch {
            guard !Task.isCancelled else { return }
            items = []
            canLoadMore = false
            feedState = .error(error.localizedDescription)
        }
    }

    private func loadNextPage() async {
        guard let cursor = items.last?.post.createdAt else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let posts = try await postRepository.fetchPosts(
                communityId: communityId,
                limit: pageSize,
                before: cursor
            )
            guard !Task.isCancelled else { return }

            // Drop duplicates if cursor races with a fresh prepend.
            let existingIds = Set(items.map(\.id))
            let fresh = posts.filter { !existingIds.contains($0.id) }
            let pageItems = try await makeItems(from: fresh)
            guard !Task.isCancelled else { return }

            items.append(contentsOf: pageItems)
            canLoadMore = posts.count == pageSize
            feedState = items.isEmpty ? .empty : .loaded(items)
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
        }
    }

    private func makeItems(from posts: [CommunityPost]) async throws -> [CommunityPostItem] {
        let missingIds = posts
            .map(\.authorId)
            .filter { authorCache[$0] == nil }

        if !missingIds.isEmpty {
            let fetched = try await userRepository.fetchProfiles(userIds: missingIds)
            for (id, user) in fetched {
                authorCache[id] = user
            }
        }

        return posts.map { post in
            CommunityPostItem(post: post, author: authorCache[post.authorId])
        }
    }

    private func author(for userId: String) async -> User? {
        if let cached = authorCache[userId] {
            return cached
        }
        if let fetched = try? await userRepository.fetchProfiles(userIds: [userId])[userId] {
            authorCache[userId] = fetched
            return fetched
        }
        // Fallback: self from auth if batch miss (rare).
        if authRepository.currentUser?.id == userId {
            return authRepository.currentUser
        }
        return nil
    }

    private func cancelLoads() {
        loadTask?.cancel()
        loadMoreTask?.cancel()
        loadTask = nil
        loadMoreTask = nil
    }
}

private extension ViewState {
    var isLoadedOrEmpty: Bool {
        switch self {
        case .loaded, .empty:
            return true
        default:
            return false
        }
    }
}
