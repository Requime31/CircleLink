import Combine
import Foundation

@MainActor
final class CommunityDetailViewModel: ObservableObject {
    @Published private(set) var communityState: ViewState<Community> = .idle
    @Published private(set) var membersState: ViewState<[User]> = .idle
    @Published private(set) var isMember = false
    @Published private(set) var isMembershipActionInFlight = false
    @Published private(set) var isOpeningGroupChat = false
    @Published private(set) var membershipErrorMessage: String?
    @Published private(set) var postsState: ViewState<[CommunityPost]> = .idle
    @Published private(set) var posts: [CommunityPost] = []
    @Published private(set) var postAuthors: [String: User] = [:]
    @Published private(set) var isPosting = false
    @Published private(set) var isUpdatingCover = false
    @Published private(set) var postErrorMessage: String?

    let communityId: String

    /// Used by the View to skip opening peer profile for the current user.
    var currentUserId: String? { authRepository.currentUser?.id }
    var canEditCover: Bool { communityState.loadedValue?.creatorId == currentUserId }

    private let communityRepository: CommunityRepository
    private let chatRepository: ChatRepository
    private let authRepository: AuthRepository
    private let communityPostRepository: CommunityPostRepository
    private let communityImageStorage: CommunityImageStorage
    private let userRepository: UserRepository
    private var communityLoadGeneration = 0
    private var membersLoadGeneration = 0
    private var postsLoadGeneration = 0
    private var loadGeneration = 0

    init(
        communityId: String,
        communityRepository: CommunityRepository,
        chatRepository: ChatRepository,
        authRepository: AuthRepository,
        communityPostRepository: CommunityPostRepository,
        communityImageStorage: CommunityImageStorage,
        userRepository: UserRepository
    ) {
        self.communityId = communityId
        self.communityRepository = communityRepository
        self.chatRepository = chatRepository
        self.authRepository = authRepository
        self.communityPostRepository = communityPostRepository
        self.communityImageStorage = communityImageStorage
        self.userRepository = userRepository
    }

    func load() async {
        loadGeneration += 1
        let generation = loadGeneration
        await loadCommunity()
        guard generation == loadGeneration, !Task.isCancelled else { return }
        await loadMembers()
        guard generation == loadGeneration, !Task.isCancelled else { return }
        await loadPosts()
    }

    func reloadPosts() async {
        await loadPosts()
    }

    func join() async {
        guard !isMembershipActionInFlight else { return }
        isMembershipActionInFlight = true
        defer { isMembershipActionInFlight = false }
        membershipErrorMessage = nil

        do {
            try await communityRepository.join(communityId: communityId)
            await load()
        } catch {
            membershipErrorMessage = error.localizedDescription
        }
    }

    func leave() async {
        guard !isMembershipActionInFlight else { return }
        isMembershipActionInFlight = true
        defer { isMembershipActionInFlight = false }
        membershipErrorMessage = nil

        do {
            // Drop group chat access first — group write rules still require membership.
            try await chatRepository.leaveGroupChat(communityId: communityId)
            try await communityRepository.leave(communityId: communityId)
            await load()
        } catch {
            membershipErrorMessage = error.localizedDescription
        }
    }

    /// Creates or opens the community group chat, then returns `(chatId, title)`.
    ///
    /// Flow:
    /// User tap → View → this method → ChatRepository.createGroupChat
    /// → Firestore chats/{group_id} → callback opens Chat sheet.
    func openGroupChat() async -> (chatId: String, title: String)? {
        guard !isOpeningGroupChat else { return nil }
        guard isMember else {
            membershipErrorMessage = "Join this community to open group chat."
            return nil
        }

        guard let currentUserId = authRepository.currentUser?.id else {
            membershipErrorMessage = "You must be signed in to open group chat."
            return nil
        }

        isOpeningGroupChat = true
        membershipErrorMessage = nil
        defer { isOpeningGroupChat = false }

        do {
            // Always refresh members so new joiners get chatRefs on open.
            let members = try await communityRepository.fetchMembers(communityId: communityId)
            membersState = members.isEmpty ? .empty : .loaded(members)
            updateMembership(from: members)
            syncDisplayedMemberCount(members.count)

            guard members.contains(where: { $0.id == currentUserId }) else {
                membershipErrorMessage = "Only community members can open this group chat."
                isMember = false
                return nil
            }

            let participantIds = members.map(\.id)
            let chatId = try await chatRepository.createGroupChat(
                communityId: communityId,
                participantIds: participantIds
            )

            let title: String
            if case let .loaded(community) = communityState {
                title = community.name
            } else {
                title = "Group Chat"
            }

            return (chatId, title)
        } catch {
            membershipErrorMessage = error.localizedDescription
            return nil
        }
    }

    func resetMembershipActionState() {
        membershipErrorMessage = nil
    }

    func canManage(_ post: CommunityPost) -> Bool {
        post.authorId == currentUserId || canEditCover
    }

    func author(for post: CommunityPost) -> User? {
        postAuthors[post.authorId]
    }

    @discardableResult
    func createPost(text: String?, image: Data?) async -> Bool {
        guard isMember, !isPosting else { return false }
        isPosting = true
        postErrorMessage = nil
        defer { isPosting = false }
        do {
            let post = try await communityPostRepository.createPost(
                communityId: communityId, postId: UUID().uuidString, text: text, image: image
            )
            postsLoadGeneration += 1
            posts.insert(post, at: 0)
            syncPostsState()
            return true
        } catch {
            postErrorMessage = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func updatePost(_ post: CommunityPost, text: String?, image: Data?, removeImage: Bool) async -> Bool {
        guard canManage(post), !isPosting else { return false }
        isPosting = true
        postErrorMessage = nil
        defer { isPosting = false }
        do {
            let updated = try await communityPostRepository.updatePost(post, text: text, image: image, removeImage: removeImage)
            postsLoadGeneration += 1
            if let index = posts.firstIndex(where: { $0.id == updated.id }) { posts[index] = updated }
            syncPostsState()
            return true
        } catch {
            postErrorMessage = error.localizedDescription
            return false
        }
    }

    func deletePost(_ post: CommunityPost) async {
        guard canManage(post), !isPosting else { return }
        isPosting = true
        postErrorMessage = nil
        defer { isPosting = false }
        do {
            try await communityPostRepository.deletePost(post)
            postsLoadGeneration += 1
            posts.removeAll { $0.id == post.id }
            syncPostsState()
        } catch { postErrorMessage = error.localizedDescription }
    }

    func updateCover(image: Data?) async {
        guard canEditCover, !isUpdatingCover else { return }
        isUpdatingCover = true
        membershipErrorMessage = nil
        defer { isUpdatingCover = false }
        do {
            if let image {
                let url = try await communityImageStorage.uploadCover(
                    data: ImageCompressor.compressForChat(image), communityId: communityId
                )
                try await communityRepository.updateCoverURL(communityId: communityId, url: url)
            } else {
                try await communityRepository.updateCoverURL(communityId: communityId, url: nil)
                try? await communityImageStorage.deleteCover(communityId: communityId)
            }
            await loadCommunity()
        } catch { membershipErrorMessage = error.localizedDescription }
    }

    func clearPostError() { postErrorMessage = nil }

    private func loadCommunity() async {
        communityLoadGeneration += 1
        let generation = communityLoadGeneration
        communityState = .loading

        do {
            let communities = try await communityRepository.fetchCommunities()
            guard generation == communityLoadGeneration, !Task.isCancelled else { return }
            if let community = communities.first(where: { $0.id == communityId }) {
                communityState = .loaded(community)
            } else {
                communityState = .error("Community not found.")
            }
        } catch {
            guard generation == communityLoadGeneration, !Task.isCancelled else { return }
            communityState = .error(error.localizedDescription)
        }
    }

    private func loadMembers() async {
        membersLoadGeneration += 1
        let generation = membersLoadGeneration
        membersState = .loading

        do {
            let members = try await communityRepository.fetchMembers(communityId: communityId)
            guard generation == membersLoadGeneration, !Task.isCancelled else { return }
            membersState = members.isEmpty ? .empty : .loaded(members)
            updateMembership(from: members)
            syncDisplayedMemberCount(members.count)
        } catch {
            guard generation == membersLoadGeneration, !Task.isCancelled else { return }
            membersState = .error(error.localizedDescription)
        }
    }

    private func loadPosts() async {
        postsLoadGeneration += 1
        let generation = postsLoadGeneration
        postsState = .loading
        postErrorMessage = nil
        do {
            let loaded = try await communityPostRepository.fetchPosts(communityId: communityId, limit: 50, before: nil)
            guard generation == postsLoadGeneration, !Task.isCancelled else { return }
            posts = loaded
            await loadPostAuthors(for: loaded)
            guard generation == postsLoadGeneration, !Task.isCancelled else { return }
            syncPostsState()
        } catch {
            guard generation == postsLoadGeneration, !Task.isCancelled else { return }
            postsState = .error(error.localizedDescription)
        }
    }

    private func syncPostsState() {
        postsState = posts.isEmpty ? .empty : .loaded(posts)
    }

    private func loadPostAuthors(for posts: [CommunityPost]) async {
        var authors = postAuthors
        if case let .loaded(members) = membersState {
            for member in members { authors[member.id] = member }
        }

        let missingIds = Set(posts.map(\.authorId)).subtracting(authors.keys)
        await withTaskGroup(of: (String, User?).self) { group in
            for userId in missingIds {
                group.addTask { [userRepository] in
                    (userId, try? await userRepository.fetchProfile(userId: userId))
                }
            }
            for await (userId, user) in group {
                if let user { authors[userId] = user }
            }
        }
        guard !Task.isCancelled else { return }
        postAuthors = authors
    }

    private func updateMembership(from members: [User]) {
        guard let currentUserId = authRepository.currentUser?.id else {
            isMember = false
            return
        }
        isMember = members.contains { $0.id == currentUserId }
    }

    private func syncDisplayedMemberCount(_ count: Int) {
        guard case let .loaded(community) = communityState else { return }
        guard community.memberCount != count else { return }
        var updated = community
        updated.memberCount = count
        communityState = .loaded(updated)
    }
}

private extension ViewState {
    var loadedValue: T? {
        if case let .loaded(value) = self { return value }
        return nil
    }
}
