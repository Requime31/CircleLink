import Combine
import Foundation

enum CommunityCoverEdit: Equatable, Sendable {
    case unchanged
    case replace(Data)
    case remove
}

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
    @Published private(set) var isSavingCommunity = false
    @Published private(set) var communityEditErrorMessage: String?
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
            isMember = true
            await refreshAfterMembershipChange()
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
            isMember = false
            await refreshAfterMembershipChange()
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
                title = CommunityContentPolicy.safeDisplayName(community.name)
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
        guard case let .loaded(community) = communityState else { return }
        _ = await saveCommunity(
            name: community.name,
            description: community.description,
            coverEdit: image.map(CommunityCoverEdit.replace) ?? .remove
        )
    }

    @discardableResult
    func saveCommunity(name: String, description: String, coverEdit: CommunityCoverEdit) async -> Bool {
        guard canEditCover else {
            communityEditErrorMessage = "Only the community owner can edit it."
            return false
        }
        guard !isSavingCommunity else { return false }
        let content: ValidatedCommunityContent
        do {
            content = try CommunityContentPolicy.validate(name: name, description: description)
        } catch {
            communityEditErrorMessage = error.localizedDescription
            return false
        }

        isSavingCommunity = true
        isUpdatingCover = coverEdit != .unchanged
        communityEditErrorMessage = nil
        defer {
            isSavingCommunity = false
            isUpdatingCover = false
        }

        do {
            try await communityRepository.updateCommunityMetadata(
                communityId: communityId,
                name: content.name,
                description: content.description
            )

            switch coverEdit {
            case .unchanged:
                break
            case let .replace(data):
                do {
                    let url = try await communityImageStorage.uploadCover(
                        data: ImageCompressor.compressForChat(data),
                        communityId: communityId
                    )
                    try await communityRepository.updateCoverURL(communityId: communityId, url: url)
                } catch {
                    await loadCommunity()
                    communityEditErrorMessage = "Name and description were saved, but the cover wasn’t. Try Save again to retry the cover."
                    return false
                }
            case .remove:
                try await communityRepository.updateCoverURL(communityId: communityId, url: nil)
                // The visible Firestore reference is authoritative. Storage cleanup can be retried later.
                try? await communityImageStorage.deleteCover(communityId: communityId)
            }

            await loadCommunity()
            return true
        } catch {
            communityEditErrorMessage = error.localizedDescription
            return false
        }
    }

    func clearCommunityEditError() { communityEditErrorMessage = nil }

    func clearPostError() { postErrorMessage = nil }

    private func refreshAfterMembershipChange() async {
        // Preserve the visible detail screen while refreshing authoritative counts
        // and members. Re-entering `.loading` here causes a full-screen flash.
        await loadCommunity(showLoading: false)
        guard !Task.isCancelled else { return }
        await loadMembers(showLoading: false)
    }

    private func loadCommunity(showLoading: Bool = true) async {
        communityLoadGeneration += 1
        let generation = communityLoadGeneration
        if showLoading { communityState = .loading }

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

    private func loadMembers(showLoading: Bool = true) async {
        membersLoadGeneration += 1
        let generation = membersLoadGeneration
        if showLoading { membersState = .loading }

        do {
            let members = try await communityRepository.fetchMembers(communityId: communityId)
            guard generation == membersLoadGeneration, !Task.isCancelled else { return }
            membersState = members.isEmpty ? .empty : .loaded(members)
            updateMembership(from: members)
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
        let authorIds = Set(posts.map(\.authorId))
        var authors: [String: User] = [:]
        if case let .loaded(members) = membersState {
            for member in members where authorIds.contains(member.id) && member.isSociallyAvailable {
                authors[member.id] = member
            }
        }

        // Refetch every non-member author on refresh so a previously cached
        // active profile disappears promptly after account deactivation.
        let missingIds = authorIds.subtracting(authors.keys)
        await withTaskGroup(of: (String, User?).self) { group in
            for userId in missingIds {
                group.addTask { [userRepository] in
                    (userId, try? await userRepository.fetchProfile(userId: userId))
                }
            }
            for await (userId, user) in group {
                if let user, user.isSociallyAvailable { authors[userId] = user }
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

}

private extension ViewState {
    var loadedValue: T? {
        if case let .loaded(value) = self { return value }
        return nil
    }
}
