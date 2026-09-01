import Foundation
@testable import CircleLink

/// Shared ordered call log so tests can assert cross-repository call order.
final class MockCallLog: @unchecked Sendable {
    private(set) var entries: [String] = []

    func append(_ entry: String) {
        entries.append(entry)
    }

    func reset() {
        entries = []
    }
}

// MARK: - Auth

final class MockAuthRepository: AuthRepository, @unchecked Sendable {
    var currentUser: User?
    var reauthenticationMethod: ReauthenticationMethod = .email(address: "test@example.com")
    var signInWithAppleResult: Result<User, Error> = .success(MockAuthRepository.sampleUser)
    var signInWithEmailResult: Result<User, Error> = .success(MockAuthRepository.sampleUser)
    var signUpWithEmailResult: Result<User, Error> = .success(MockAuthRepository.sampleUser)
    var signInWithAppleCallCount = 0
    var signInWithEmailCallCount = 0
    var signUpWithEmailCallCount = 0
    var reauthenticateWithAppleCallCount = 0
    var reauthenticateWithEmailCallCount = 0
    var reauthenticationError: Error?
    var lastEmail: String?
    var lastPassword: String?

    init(currentUser: User? = nil) {
        self.currentUser = currentUser
    }

    func signInWithApple() async throws -> User {
        signInWithAppleCallCount += 1
        let user = try signInWithAppleResult.get()
        currentUser = user
        return user
    }

    func signInWithEmail(email: String, password: String) async throws -> User {
        signInWithEmailCallCount += 1
        lastEmail = email
        lastPassword = password
        let user = try signInWithEmailResult.get()
        currentUser = user
        return user
    }

    func signUpWithEmail(email: String, password: String) async throws -> User {
        signUpWithEmailCallCount += 1
        lastEmail = email
        lastPassword = password
        let user = try signUpWithEmailResult.get()
        currentUser = user
        return user
    }

    func reauthenticateWithApple() async throws {
        reauthenticateWithAppleCallCount += 1
        if let reauthenticationError { throw reauthenticationError }
    }

    func reauthenticateWithEmail(password: String) async throws {
        reauthenticateWithEmailCallCount += 1
        lastPassword = password
        if let reauthenticationError { throw reauthenticationError }
    }

    func signOut() throws {
        currentUser = nil
    }

    static let sampleUser = User(
        id: "user-1",
        displayName: "Test User",
        avatarURL: nil,
        avatarBase64: nil,
        interests: ["Sports", "Music", "Art"],
        ageConfirmedAt: Date()
    )
}

// MARK: - Chat

final class MockChatRepository: ChatRepository, @unchecked Sendable {
    var messages: [Message] = []
    var visibleChats: [ChatSummary] = []
    var hiddenChats: [ChatSummary] = []
    var fetchOrganizedChatsError: Error?
    var sendError: Error?
    var createDirectChatResult: String = "direct-chat-1"
    var createDirectChatError: Error?
    var createGroupChatResult: String = "group_community-1"
    var createGroupChatError: Error?
    var leaveGroupChatError: Error?
    var leaveChatError: Error?
    var setMutedError: Error?
    var setPinnedError: Error?
    var reorderPinnedError: Error?
    var hideChatError: Error?
    var unhideChatError: Error?
    var clearHistoryError: Error?
    var deleteDirectChatError: Error?
    var createDirectChatCallCount = 0
    var createGroupChatCallCount = 0
    var leaveGroupChatCallCount = 0
    var leaveChatCallCount = 0
    var setMutedCallCount = 0
    var setPinnedCallCount = 0
    var reorderPinnedCallCount = 0
    var pinnedRequests: [(chatId: String, pinned: Bool)] = []
    var reorderedPinnedChatIds: [[String]] = []
    var hideChatCallCount = 0
    var unhideChatCallCount = 0
    var clearHistoryCallCount = 0
    var deleteDirectChatCallCount = 0
    var leaveChatIds: [String] = []
    var hideChatIds: [String] = []
    var deleteDirectChatIds: [String] = []
    var isMutedByChatId: [String: Bool] = [:]
    var foreignChatIds: Set<String> = []
    var clearedAtByChatId: [String: Date] = [:]
    var chatInfoType: ChatType = .direct
    var chatInfoParticipants: [User] = []
    var lastCreateDirectPeerId: String?
    var deactivatedPeerIds: Set<String> = []
    var lastCreateGroupCommunityId: String?
    var lastLeaveGroupCommunityId: String?
    var sentClientMessageIds: [String] = []
    var callLog: MockCallLog?
    var liveContinuation: AsyncStream<Message>.Continuation?
    var shouldSuspendMessageFetch = false
    var shouldSuspendOrganizedFetch = false
    var shouldSuspendPinMutation = false
    var shouldSuspendPinnedReorder = false
    private var pendingMessageFetchContinuation: CheckedContinuation<Void, Never>?
    private var pendingOrganizedFetchContinuation: CheckedContinuation<Void, Never>?
    private var pendingPinMutationContinuation: CheckedContinuation<Void, Never>?
    private var pendingPinnedReorderContinuation: CheckedContinuation<Void, Never>?

    var hasPendingMessageFetch: Bool {
        pendingMessageFetchContinuation != nil
    }

    var hasPendingOrganizedFetch: Bool { pendingOrganizedFetchContinuation != nil }
    var hasPendingPinMutation: Bool { pendingPinMutationContinuation != nil }
    var hasPendingPinnedReorder: Bool { pendingPinnedReorderContinuation != nil }

    func resumeMessageFetch() {
        shouldSuspendMessageFetch = false
        pendingMessageFetchContinuation?.resume()
        pendingMessageFetchContinuation = nil
    }

    func resumeOrganizedFetch() {
        shouldSuspendOrganizedFetch = false
        pendingOrganizedFetchContinuation?.resume()
        pendingOrganizedFetchContinuation = nil
    }

    func resumePinMutation() {
        shouldSuspendPinMutation = false
        pendingPinMutationContinuation?.resume()
        pendingPinMutationContinuation = nil
    }

    func resumePinnedReorder() {
        shouldSuspendPinnedReorder = false
        pendingPinnedReorderContinuation?.resume()
        pendingPinnedReorderContinuation = nil
    }

    func fetchChats() async throws -> [ChatSummary] { visibleChats }

    func fetchHiddenChats() async throws -> [ChatSummary] { hiddenChats }

    func fetchOrganizedChats() async throws -> OrganizedChats {
        let snapshot = OrganizedChats(visible: visibleChats, hidden: hiddenChats)
        if shouldSuspendOrganizedFetch {
            await withCheckedContinuation { pendingOrganizedFetchContinuation = $0 }
        }
        if let fetchOrganizedChatsError { throw fetchOrganizedChatsError }
        return snapshot
    }

    func fetchChatInfo(chatId: String) async throws -> ChatInfo {
        ChatInfo(
            id: chatId,
            type: chatInfoType,
            title: "Chat",
            communityId: nil,
            participants: chatInfoParticipants,
            isMuted: isMutedByChatId[chatId] ?? false,
            clearedAt: clearedAtByChatId[chatId]
        )
    }

    func leaveChat(chatId: String) async throws {
        leaveChatCallCount += 1
        leaveChatIds.append(chatId)
        if let leaveChatError { throw leaveChatError }
    }

    func setChatMuted(chatId: String, muted: Bool) async throws {
        setMutedCallCount += 1
        isMutedByChatId[chatId] = muted
        if let setMutedError { throw setMutedError }
        if let index = visibleChats.firstIndex(where: { $0.id == chatId }) {
            visibleChats[index].isMuted = muted
        }
        if let index = hiddenChats.firstIndex(where: { $0.id == chatId }) {
            hiddenChats[index].isMuted = muted
        }
    }

    func setChatPinned(chatId: String, pinned: Bool) async throws {
        setPinnedCallCount += 1
        pinnedRequests.append((chatId, pinned))
        if shouldSuspendPinMutation {
            await withCheckedContinuation { pendingPinMutationContinuation = $0 }
        }
        if let setPinnedError { throw setPinnedError }
        guard !foreignChatIds.contains(chatId) else {
            throw ChatPinningError.notParticipant(chatId)
        }
        if hiddenChats.contains(where: { $0.id == chatId }) {
            throw ChatPinningError.hiddenChat(chatId)
        }
        guard let index = visibleChats.firstIndex(where: { $0.id == chatId }) else {
            throw ChatPinningError.unknownChat(chatId)
        }
        if pinned {
            if visibleChats[index].isPinned, visibleChats[index].pinOrder != nil { return }
            let nextOrder = visibleChats.compactMap(\.pinOrder).max().map { $0 + 1 } ?? 0
            visibleChats[index].isPinned = true
            visibleChats[index].pinOrder = nextOrder
        } else {
            visibleChats[index].isPinned = false
            visibleChats[index].pinOrder = nil
        }
    }

    func reorderPinnedChats(chatIds: [String]) async throws {
        reorderPinnedCallCount += 1
        reorderedPinnedChatIds.append(chatIds)
        if shouldSuspendPinnedReorder {
            await withCheckedContinuation { pendingPinnedReorderContinuation = $0 }
        }
        guard Set(chatIds).count == chatIds.count else {
            throw ChatPinningError.duplicateChatIDs
        }
        for chatId in chatIds {
            if hiddenChats.contains(where: { $0.id == chatId }) {
                throw ChatPinningError.hiddenChat(chatId)
            }
            guard visibleChats.contains(where: { $0.id == chatId }) else {
                throw ChatPinningError.unknownChat(chatId)
            }
            guard !foreignChatIds.contains(chatId) else {
                throw ChatPinningError.notParticipant(chatId)
            }
        }
        let currentPinned = Set(visibleChats.filter(\.isPinned).map(\.id))
        guard currentPinned == Set(chatIds) else {
            throw ChatPinningError.incompletePinnedSet
        }
        if let reorderPinnedError { throw reorderPinnedError }

        let ranks = Dictionary(uniqueKeysWithValues: chatIds.enumerated().map { ($0.element, $0.offset) })
        for index in visibleChats.indices where visibleChats[index].isPinned {
            visibleChats[index].pinOrder = ranks[visibleChats[index].id]
        }
    }

    func hideChat(chatId: String) async throws {
        hideChatCallCount += 1
        hideChatIds.append(chatId)
        if let hideChatError { throw hideChatError }
        if let index = visibleChats.firstIndex(where: { $0.id == chatId }) {
            var chat = visibleChats.remove(at: index)
            chat.isPinned = false
            chat.pinOrder = nil
            hiddenChats.append(chat)
        }
    }

    func unhideChat(chatId: String) async throws {
        unhideChatCallCount += 1
        if let unhideChatError { throw unhideChatError }
    }

    func clearChatHistory(chatId: String) async throws {
        clearHistoryCallCount += 1
        clearedAtByChatId[chatId] = Date()
        if let clearHistoryError { throw clearHistoryError }
    }

    func deleteDirectChat(chatId: String) async throws {
        deleteDirectChatCallCount += 1
        deleteDirectChatIds.append(chatId)
        if let deleteDirectChatError { throw deleteDirectChatError }
    }

    func fetchMessages(chatId: String, limit: Int, before: MessagePageCursor?) async throws -> [Message] {
        if shouldSuspendMessageFetch {
            await withCheckedContinuation { continuation in
                pendingMessageFetchContinuation = continuation
            }
        }
        let watermark = clearedAtByChatId[chatId]
        let filtered: [Message]
        if let before {
            filtered = messages.filter {
                isBefore($0, cursor: before)
                    && $0.chatId == chatId
                    && isVisible($0, clearedAt: watermark)
            }
        } else {
            filtered = messages.filter {
                $0.chatId == chatId && isVisible($0, clearedAt: watermark)
            }
        }
        return Array(filtered.sorted(by: newestFirst).prefix(limit))
            .sorted {
                $0.createdAt == $1.createdAt ? $0.id < $1.id : $0.createdAt < $1.createdAt
            }
    }

    func fetchChatMedia(chatId: String, limit: Int, before: MessagePageCursor?) async throws -> [Message] {
        let watermark = clearedAtByChatId[chatId]
        var filtered = messages.filter {
            $0.chatId == chatId
                && $0.imageURL != nil
                && isVisible($0, clearedAt: watermark)
        }
        if let before {
            filtered = filtered.filter { isBefore($0, cursor: before) }
        }
        return Array(filtered.sorted(by: newestFirst).prefix(limit))
    }

    private func newestFirst(_ lhs: Message, _ rhs: Message) -> Bool {
        lhs.createdAt == rhs.createdAt ? lhs.id > rhs.id : lhs.createdAt > rhs.createdAt
    }

    private func isBefore(_ message: Message, cursor: MessagePageCursor) -> Bool {
        message.createdAt < cursor.createdAt
            || (message.createdAt == cursor.createdAt && message.id < cursor.messageId)
    }

    private func isVisible(_ message: Message, clearedAt: Date?) -> Bool {
        guard let clearedAt else { return true }
        return message.createdAt > clearedAt
    }

    func sendMessage(chatId: String, text: String?, image: Data?, clientMessageId: String) async throws {
        sentClientMessageIds.append(clientMessageId)
        if let sendError {
            throw sendError
        }
        let message = Message(
            id: clientMessageId,
            chatId: chatId,
            senderId: "user-1",
            text: text,
            imageURL: nil,
            createdAt: Date(),
            clientMessageId: clientMessageId,
            status: .sent
        )
        messages.append(message)
        liveContinuation?.yield(message)
    }

    func observeLiveMessages(chatId: String) -> AsyncStream<Message> {
        AsyncStream { continuation in
            liveContinuation = continuation
            continuation.onTermination = { [weak self] _ in
                self?.liveContinuation = nil
            }
        }
    }

    func createDirectChat(with userId: String) async throws -> String {
        createDirectChatCallCount += 1
        lastCreateDirectPeerId = userId
        if deactivatedPeerIds.contains(userId) { throw FirestoreChatError.deactivatedAccount }
        callLog?.append("createDirectChat")
        if let createDirectChatError { throw createDirectChatError }
        return createDirectChatResult
    }

    func createGroupChat(communityId: String, participantIds: [String]) async throws -> String {
        createGroupChatCallCount += 1
        lastCreateGroupCommunityId = communityId
        callLog?.append("createGroupChat")
        if let createGroupChatError { throw createGroupChatError }
        return createGroupChatResult
    }

    func leaveGroupChat(communityId: String) async throws {
        leaveGroupChatCallCount += 1
        lastLeaveGroupCommunityId = communityId
        callLog?.append("leaveGroupChat")
        if let leaveGroupChatError { throw leaveGroupChatError }
    }
}

// MARK: - Connection

final class MockConnectionRepository: ConnectionRepository, @unchecked Sendable {
    var candidates: [User] = []
    var incoming: [ConnectionRequest] = []
    var matched: [ConnectionRequest] = []
    var outgoingPending: [ConnectionRequest] = []
    var outgoingPendingError: Error?
    var outgoingPendingFetchCallCount = 0
    var shouldSuspendOutgoingPending = false
    private var outgoingPendingContinuation: CheckedContinuation<Void, Never>?
    var hasPendingOutgoingPendingFetch: Bool { outgoingPendingContinuation != nil }
    var respondError: Error?
    var sendConnectError: Error?
    var acceptCallCount = 0
    var declineCallCount = 0
    var cancelOutgoingCallCount = 0
    var lastCancelledOutgoingRequestId: String?
    var sendConnectCallCount = 0
    var lastSendConnectUserId: String?
    var lastSendConnectCommunityId: String?
    var deactivatedPeerIds: Set<String> = []

    func fetchCandidates() async throws -> [User] { candidates }

    func sendConnect(to userId: String) async throws {
        sendConnectCallCount += 1
        lastSendConnectUserId = userId
        lastSendConnectCommunityId = nil
        if deactivatedPeerIds.contains(userId) { throw FirestoreConnectionError.deactivatedAccount }
        if let sendConnectError { throw sendConnectError }
    }

    func fetchIncomingRequests() async throws -> [ConnectionRequest] { incoming }

    func fetchOutgoingPendingRequests() async throws -> [ConnectionRequest] {
        outgoingPendingFetchCallCount += 1
        if shouldSuspendOutgoingPending {
            await withCheckedContinuation { outgoingPendingContinuation = $0 }
        }
        if let outgoingPendingError { throw outgoingPendingError }
        return outgoingPending
            .filter { $0.status == .pending }
            .sorted {
                if $0.createdAt != $1.createdAt { return $0.createdAt > $1.createdAt }
                return $0.id < $1.id
            }
    }

    func resumeOutgoingPendingFetch() {
        shouldSuspendOutgoingPending = false
        outgoingPendingContinuation?.resume()
        outgoingPendingContinuation = nil
    }

    func fetchMatchedConnections() async throws -> [ConnectionRequest] { matched }

    func respond(to requestId: String, accept: Bool) async throws {
        if let respondError { throw respondError }
        if accept {
            acceptCallCount += 1
            if let index = incoming.firstIndex(where: { $0.id == requestId }) {
                let request = incoming.remove(at: index)
                matched.append(request)
            }
        } else {
            declineCallCount += 1
            incoming.removeAll { $0.id == requestId }
        }
    }

    func cancelOutgoingRequest(requestId: String) async throws {
        if let respondError { throw respondError }
        cancelOutgoingCallCount += 1
        lastCancelledOutgoingRequestId = requestId
        outgoingPending.removeAll { $0.id == requestId && $0.status == .pending }
    }

    func fetchConnection(with peerId: String) async throws -> ConnectionRequest? {
        matched.first { $0.fromUserId == peerId || $0.toUserId == peerId }
            ?? incoming.first { $0.fromUserId == peerId || $0.toUserId == peerId }
    }

    func removeConnection(with peerId: String) async throws {
        matched.removeAll { $0.fromUserId == peerId || $0.toUserId == peerId }
        incoming.removeAll { $0.fromUserId == peerId || $0.toUserId == peerId }
    }
}

// MARK: - Community / User

final class MockCommunityRepository: CommunityRepository, @unchecked Sendable {
    var communities: [Community] = [
        Community(
            id: "community-1",
            name: "Swift Devs",
            description: "iOS chat",
            interestTag: "Swift",
            memberCount: 2
        )
    ]
    var membersByCommunity: [String: [User]] = [
        "community-1": [MockAuthRepository.sampleUser]
    ]
    var fetchCommunitiesError: Error?
    var fetchMembersError: Error?
    var joinError: Error?
    var leaveError: Error?
    var joinCallCount = 0
    var leaveCallCount = 0
    var createCallCount = 0
    var updateMetadataCallCount = 0
    var updateMetadataError: Error?
    var updateCoverError: Error?
    var lastCreatedName: String?
    var lastCreatedDescription: String?
    var lastJoinedCommunityId: String?
    var lastLeftCommunityId: String?
    var callLog: MockCallLog?

    func fetchCommunities() async throws -> [Community] {
        if let fetchCommunitiesError { throw fetchCommunitiesError }
        return communities
    }

    func fetchMembers(communityId: String) async throws -> [User] {
        if let fetchMembersError { throw fetchMembersError }
        return membersByCommunity[communityId] ?? []
    }

    func join(communityId: String) async throws {
        joinCallCount += 1
        lastJoinedCommunityId = communityId
        callLog?.append("community.join")
        if let joinError { throw joinError }
        var members = membersByCommunity[communityId] ?? []
        if !members.contains(where: { $0.id == MockAuthRepository.sampleUser.id }) {
            members.append(MockAuthRepository.sampleUser)
        }
        membersByCommunity[communityId] = members
    }

    func leave(communityId: String) async throws {
        leaveCallCount += 1
        lastLeftCommunityId = communityId
        callLog?.append("community.leave")
        if let leaveError { throw leaveError }
        membersByCommunity[communityId]?.removeAll { $0.id == MockAuthRepository.sampleUser.id }
    }

    func updateCoverURL(communityId: String, url: URL?) async throws {
        if let updateCoverError { throw updateCoverError }
        guard let index = communities.firstIndex(where: { $0.id == communityId }) else { return }
        let community = communities[index]
        communities[index] = Community(
            id: community.id, name: community.name, description: community.description,
            interestTag: community.interestTag, memberCount: community.memberCount,
            coverImageURL: url, createdAt: community.createdAt, creatorId: community.creatorId
        )
    }

    func updateCommunityMetadata(communityId: String, name: String, description: String) async throws {
        updateMetadataCallCount += 1
        if let updateMetadataError { throw updateMetadataError }
        let content = try CommunityContentPolicy.validate(name: name, description: description)
        guard let index = communities.firstIndex(where: { $0.id == communityId }) else { return }
        let community = communities[index]
        communities[index] = Community(
            id: community.id, name: content.name, description: content.description,
            interestTag: community.interestTag, memberCount: community.memberCount,
            coverImageURL: community.coverImageURL, createdAt: community.createdAt,
            creatorId: community.creatorId
        )
    }

    func createCommunity(name: String, description: String, interestTag: String) async throws -> Community {
        createCallCount += 1
        lastCreatedName = name
        lastCreatedDescription = description
        let community = Community(
            id: "community-new",
            name: name,
            description: description,
            interestTag: interestTag,
            memberCount: 1
        )
        communities.append(community)
        return community
    }

    var joinedCommunityCount = 0
    var communitiesForUser: [String: [Community]] = [:]

    func fetchJoinedCommunityCount() async throws -> Int {
        joinedCommunityCount
    }

    func fetchCommunities(forUserId userId: String) async throws -> [Community] {
        communitiesForUser[userId] ?? communities
    }
}

// MARK: - Profile posts

final class MockProfilePostRepository: ProfilePostRepository, @unchecked Sendable {
    var posts: [ProfilePost] = []
    var createCallCount = 0
    var updateCallCount = 0
    var deleteCallCount = 0
    var createError: Error?
    var updateError: Error?
    var fetchError: Error?
    var lastUpdateText: String?
    var lastUpdateImage: Data?
    var lastUpdateRemoveImage = false
    var shouldSuspendUpdate = false
    private var updateContinuation: CheckedContinuation<Void, Never>?
    var hasPendingUpdate: Bool { updateContinuation != nil }
    /// When true, `fetchPosts` / `fetchPostCount` fail after the first successful create.
    var failReadsAfterCreate = false
    private var didCreate = false

    func fetchPosts(userId: String, limit: Int, before: Date?) async throws -> [ProfilePost] {
        if failReadsAfterCreate, didCreate {
            throw FirestoreProfilePostError.invalidData
        }
        if let fetchError { throw fetchError }
        let sorted = posts
            .filter { $0.authorId == userId }
            .sorted { $0.createdAt > $1.createdAt }
        let filtered: [ProfilePost]
        if let before {
            filtered = sorted.filter { $0.createdAt < before }
        } else {
            filtered = sorted
        }
        return Array(filtered.prefix(max(limit, 1)))
    }

    func fetchPostCount(userId: String) async throws -> Int {
        if failReadsAfterCreate, didCreate {
            throw FirestoreProfilePostError.invalidData
        }
        if let fetchError { throw fetchError }
        return posts.filter { $0.authorId == userId }.count
    }

    func createPost(postId: String, text: String?, image: Data?) async throws -> ProfilePost {
        createCallCount += 1
        if let createError { throw createError }
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasText = !(trimmed?.isEmpty ?? true)
        guard hasText || image != nil else {
            throw FirestoreProfilePostError.emptyContent
        }
        let post = ProfilePost(
            id: postId,
            authorId: MockAuthRepository.sampleUser.id,
            text: hasText ? trimmed : nil,
            imageURL: image == nil ? nil : URL(string: "https://example.com/\(postId).jpg"),
            createdAt: Date()
        )
        posts.insert(post, at: 0)
        didCreate = true
        return post
    }

    func updatePost(
        _ post: ProfilePost,
        text: String?,
        image: Data?,
        removeImage: Bool
    ) async throws -> ProfilePost {
        updateCallCount += 1
        lastUpdateText = text
        lastUpdateImage = image
        lastUpdateRemoveImage = removeImage
        if shouldSuspendUpdate {
            await withCheckedContinuation { updateContinuation = $0 }
        }
        if let updateError { throw updateError }
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasText = !(trimmed?.isEmpty ?? true)

        var imageURL = post.imageURL
        if image != nil {
            imageURL = URL(string: "https://example.com/\(post.id).jpg")
        } else if removeImage {
            imageURL = nil
        }

        guard hasText || imageURL != nil else {
            throw FirestoreProfilePostError.emptyContent
        }

        let updated = ProfilePost(
            id: post.id,
            authorId: post.authorId,
            text: hasText ? trimmed : nil,
            imageURL: imageURL,
            createdAt: post.createdAt
        )
        if let index = posts.firstIndex(where: { $0.id == post.id }) {
            posts[index] = updated
        } else {
            posts.insert(updated, at: 0)
        }
        return updated
    }

    func resumeUpdate() {
        updateContinuation?.resume()
        updateContinuation = nil
    }

    func deletePost(_ post: ProfilePost) async throws {
        deleteCallCount += 1
        posts.removeAll { $0.id == post.id }
    }
}

final class MockCommunityImageStorage: CommunityImageStorage, @unchecked Sendable {
    var uploadCoverCallCount = 0
    var deleteCoverCallCount = 0
    var uploadCoverError: Error?
    var deleteCoverError: Error?
    var shouldSuspendUpload = false
    private var uploadContinuation: CheckedContinuation<Void, Never>?
    var hasPendingUpload: Bool { uploadContinuation != nil }

    func uploadCover(data: Data, communityId: String) async throws -> URL {
        uploadCoverCallCount += 1
        if shouldSuspendUpload { await withCheckedContinuation { uploadContinuation = $0 } }
        if let uploadCoverError { throw uploadCoverError }
        return URL(string: "https://example.com/communities/\(communityId)/cover.jpg")!
    }

    func uploadPostImage(data: Data, communityId: String, postId: String) async throws -> URL {
        URL(string: "https://example.com/communityPosts/\(communityId)/\(postId).jpg")!
    }

    func deleteCover(communityId: String) async throws {
        deleteCoverCallCount += 1
        if let deleteCoverError { throw deleteCoverError }
    }

    func deletePostImage(communityId: String, postId: String) async throws {}

    func resumeUpload() {
        uploadContinuation?.resume()
        uploadContinuation = nil
    }
}

final class MockModerationRepository: ModerationRepository, @unchecked Sendable {
    var blockedUserIds: Set<String> = []
    var reportCallCount = 0
    var blockCallCount = 0
    var blockError: Error?
    var fetchBlockedError: Error?
    var unblockError: Error?
    var shouldSuspendBlock = false
    var shouldSuspendBlockedFetch = false
    var shouldSuspendUnblock = false
    private var blockContinuation: CheckedContinuation<Void, Error>?
    private var blockedFetchContinuation: CheckedContinuation<Void, Never>?
    private var unblockContinuation: CheckedContinuation<Void, Error>?
    var unblockCallCount = 0
    var hasPendingBlockedFetch: Bool { blockedFetchContinuation != nil }
    var hasPendingUnblock: Bool { unblockContinuation != nil }

    func reportUser(
        userId: String,
        reason: ReportReason,
        chatId: String?,
        communityId: String?
    ) async throws {
        reportCallCount += 1
    }

    func blockUser(_ userId: String) async throws {
        blockCallCount += 1
        if shouldSuspendBlock {
            try await withCheckedThrowingContinuation { continuation in
                blockContinuation = continuation
            }
        }
        if let blockError { throw blockError }
        blockedUserIds.insert(userId)
    }

    func resumeBlock() {
        shouldSuspendBlock = false
        blockContinuation?.resume()
        blockContinuation = nil
    }

    func unblockUser(_ userId: String) async throws {
        unblockCallCount += 1
        if shouldSuspendUnblock {
            try await withCheckedThrowingContinuation { continuation in
                unblockContinuation = continuation
            }
        }
        if let unblockError { throw unblockError }
        blockedUserIds.remove(userId)
    }

    func fetchBlockedUserIds() async throws -> Set<String> {
        if shouldSuspendBlockedFetch {
            await withCheckedContinuation { continuation in
                blockedFetchContinuation = continuation
            }
        }
        if let fetchBlockedError { throw fetchBlockedError }
        return blockedUserIds
    }

    func resumeBlockedFetch() {
        shouldSuspendBlockedFetch = false
        blockedFetchContinuation?.resume()
        blockedFetchContinuation = nil
    }

    func resumeUnblock() {
        shouldSuspendUnblock = false
        unblockContinuation?.resume()
        unblockContinuation = nil
    }
}

final class MockUserRepository: UserRepository, @unchecked Sendable {
    var profiles: [String: User] = [
        MockAuthRepository.sampleUser.id: MockAuthRepository.sampleUser,
        "peer-1": User(
            id: "peer-1",
            displayName: "Peer",
            avatarURL: nil,
            avatarBase64: nil,
            interests: ["Design", "Music", "Art"],
            ageConfirmedAt: Date()
        )
    ]
    var confirmAgeError: Error?
    var updateProfileError: Error?
    var fetchProfileError: Error?
    var confirmAgeCallCount = 0
    var confirmAgeBirthDateCallCount = 0
    var lastConfirmedBirthDate: Date?
    var updateProfileCallCount = 0
    var lastUpdatedUser: User?
    private(set) var observeProfilesCallCount = 0
    private(set) var observedProfileIDs: Set<String> = []
    private let profileObservationLock = NSLock()
    private var profileObservationContinuation: AsyncThrowingStream<User, Error>.Continuation?
    var requestAccountDeletionCallCount = 0
    var restoreAccountCallCount = 0
    var accountDeletionError: Error?
    var lifecycleCurrentUserID: String? = MockAuthRepository.sampleUser.id
    var shouldSuspendLifecycle = false
    private var lifecycleContinuation: CheckedContinuation<Void, Never>?
    var hasPendingLifecycleOperation: Bool { lifecycleContinuation != nil }

    func resumeLifecycleOperation() {
        shouldSuspendLifecycle = false
        lifecycleContinuation?.resume()
        lifecycleContinuation = nil
    }
    var shouldSuspendBirthDateConfirmation = false
    private var birthDateConfirmationContinuation: CheckedContinuation<Void, Never>?

    var hasPendingBirthDateConfirmation: Bool { birthDateConfirmationContinuation != nil }

    func resumeBirthDateConfirmation() {
        shouldSuspendBirthDateConfirmation = false
        birthDateConfirmationContinuation?.resume()
        birthDateConfirmationContinuation = nil
    }

    func fetchProfile(userId: String) async throws -> User {
        if let fetchProfileError { throw fetchProfileError }
        if let profile = profiles[userId] {
            return profile
        }
        throw NSError(domain: "MockUserRepository", code: 404, userInfo: [
            NSLocalizedDescriptionKey: "Profile not found"
        ])
    }

    func observeProfiles(userIds: Set<String>) -> AsyncThrowingStream<User, Error> {
        AsyncThrowingStream { continuation in
            profileObservationLock.lock()
            observeProfilesCallCount += 1
            observedProfileIDs = userIds
            profileObservationContinuation = continuation
            profileObservationLock.unlock()

            continuation.onTermination = { @Sendable [weak self] _ in
                guard let self else { return }
                self.profileObservationLock.lock()
                self.profileObservationContinuation = nil
                self.profileObservationLock.unlock()
            }
        }
    }

    func emitProfileChange(_ user: User) {
        profileObservationLock.lock()
        let shouldEmit = observedProfileIDs.contains(user.id)
        let continuation = profileObservationContinuation
        profileObservationLock.unlock()
        if shouldEmit {
            continuation?.yield(user)
        }
    }

    func finishProfileObservation(throwing error: Error? = nil) {
        profileObservationLock.lock()
        let continuation = profileObservationContinuation
        profileObservationContinuation = nil
        profileObservationLock.unlock()
        if let error {
            continuation?.finish(throwing: error)
        } else {
            continuation?.finish()
        }
    }

    func updateProfile(_ user: User) async throws {
        updateProfileCallCount += 1
        lastUpdatedUser = user
        if let updateProfileError { throw updateProfileError }
        profiles[user.id] = user
    }

    func confirmAge() async throws {
        confirmAgeCallCount += 1
        if let confirmAgeError { throw confirmAgeError }
        if var user = profiles[MockAuthRepository.sampleUser.id] {
            user.ageConfirmedAt = Date()
            profiles[user.id] = user
        }
    }

    func confirmAge(birthDate localBirthDate: Date) async throws {
        confirmAgeBirthDateCallCount += 1
        lastConfirmedBirthDate = localBirthDate
        if shouldSuspendBirthDateConfirmation {
            await withCheckedContinuation { continuation in
                birthDateConfirmationContinuation = continuation
            }
        }
        if let confirmAgeError { throw confirmAgeError }
        if var user = profiles[MockAuthRepository.sampleUser.id] {
            let persistedBirthDate = AgeCalculator.canonicalBirthDate(fromLocalDate: localBirthDate)
                ?? localBirthDate
            user.birthDate = persistedBirthDate
            user.age = AgeCalculator.completedYears(
                since: persistedBirthDate,
                at: Date(),
                calendar: AgeCalculator.persistedCalendar,
                timeZone: AgeCalculator.persistedTimeZone
            )
            user.ageConfirmedAt = Date()
            profiles[user.id] = user
        }
    }

    func requestAccountDeletion(now: Date) async throws {
        requestAccountDeletionCallCount += 1
        guard let expectedUserID = lifecycleCurrentUserID else { throw FirestoreUserError.notAuthenticated }
        if shouldSuspendLifecycle {
            await withCheckedContinuation { lifecycleContinuation = $0 }
        }
        guard lifecycleCurrentUserID == expectedUserID else { throw FirestoreUserError.notAuthenticated }
        if let accountDeletionError { throw accountDeletionError }
        guard var user = profiles[expectedUserID] else { return }
        guard user.accountState != .deactivated else { return }
        user.accountState = .deactivated
        user.deletionRequestedAt = now
        user.scheduledDeletionAt = AccountDeletionPolicy.scheduledDeletionDate(from: now)
        profiles[user.id] = user
    }

    func restoreAccount() async throws {
        restoreAccountCallCount += 1
        guard let expectedUserID = lifecycleCurrentUserID else { throw FirestoreUserError.notAuthenticated }
        if shouldSuspendLifecycle {
            await withCheckedContinuation { lifecycleContinuation = $0 }
        }
        guard lifecycleCurrentUserID == expectedUserID else { throw FirestoreUserError.notAuthenticated }
        if let accountDeletionError { throw accountDeletionError }
        guard var user = profiles[expectedUserID] else { return }
        user.accountState = .active
        user.deletionRequestedAt = nil
        user.scheduledDeletionAt = nil
        profiles[user.id] = user
    }

    func updateFCMToken(_ token: String) async throws {}

    func clearFCMToken() async throws {}
}
