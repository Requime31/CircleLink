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
    var signInWithAppleResult: Result<User, Error> = .success(MockAuthRepository.sampleUser)
    var signInWithEmailResult: Result<User, Error> = .success(MockAuthRepository.sampleUser)
    var signUpWithEmailResult: Result<User, Error> = .success(MockAuthRepository.sampleUser)
    var signInWithAppleCallCount = 0
    var signInWithEmailCallCount = 0
    var signUpWithEmailCallCount = 0
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
    var sendError: Error?
    var createDirectChatResult: String = "direct-chat-1"
    var createDirectChatError: Error?
    var createGroupChatResult: String = "group_community-1"
    var createGroupChatError: Error?
    var leaveGroupChatError: Error?
    var leaveChatError: Error?
    var setMutedError: Error?
    var hideChatError: Error?
    var unhideChatError: Error?
    var clearHistoryError: Error?
    var deleteDirectChatError: Error?
    var createDirectChatCallCount = 0
    var createGroupChatCallCount = 0
    var leaveGroupChatCallCount = 0
    var leaveChatCallCount = 0
    var setMutedCallCount = 0
    var hideChatCallCount = 0
    var unhideChatCallCount = 0
    var clearHistoryCallCount = 0
    var deleteDirectChatCallCount = 0
    var leaveChatIds: [String] = []
    var hideChatIds: [String] = []
    var deleteDirectChatIds: [String] = []
    var isMutedByChatId: [String: Bool] = [:]
    var clearedAtByChatId: [String: Date] = [:]
    var chatInfoType: ChatType = .direct
    var chatInfoParticipants: [User] = []
    var lastCreateDirectPeerId: String?
    var lastCreateGroupCommunityId: String?
    var lastLeaveGroupCommunityId: String?
    var sentClientMessageIds: [String] = []
    var callLog: MockCallLog?
    var liveContinuation: AsyncStream<Message>.Continuation?

    func fetchChats() async throws -> [ChatSummary] { [] }

    func fetchHiddenChats() async throws -> [ChatSummary] { [] }

    func fetchOrganizedChats() async throws -> OrganizedChats {
        OrganizedChats(visible: [], hidden: [])
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
    }

    func hideChat(chatId: String) async throws {
        hideChatCallCount += 1
        hideChatIds.append(chatId)
        if let hideChatError { throw hideChatError }
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

    func fetchMessages(chatId: String, limit: Int, before: Date?) async throws -> [Message] {
        let watermark = clearedAtByChatId[chatId]
        let filtered: [Message]
        if let before {
            filtered = messages.filter {
                $0.createdAt < before && $0.chatId == chatId && isVisible($0, clearedAt: watermark)
            }
        } else {
            filtered = messages.filter {
                $0.chatId == chatId && isVisible($0, clearedAt: watermark)
            }
        }
        return Array(filtered.sorted { $0.createdAt > $1.createdAt }.prefix(limit))
            .sorted { $0.createdAt < $1.createdAt }
    }

    func fetchChatMedia(chatId: String, limit: Int, before: Date?) async throws -> [Message] {
        let watermark = clearedAtByChatId[chatId]
        var filtered = messages.filter {
            $0.chatId == chatId
                && $0.imageURL != nil
                && isVisible($0, clearedAt: watermark)
        }
        if let before {
            filtered = filtered.filter { $0.createdAt < before }
        }
        return Array(filtered.sorted { $0.createdAt > $1.createdAt }.prefix(limit))
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
    var respondError: Error?
    var sendConnectError: Error?
    var acceptCallCount = 0
    var declineCallCount = 0
    var sendConnectCallCount = 0
    var lastSendConnectUserId: String?
    var lastSendConnectCommunityId: String?

    func fetchCandidates() async throws -> [User] { candidates }

    func sendConnect(to userId: String) async throws {
        sendConnectCallCount += 1
        lastSendConnectUserId = userId
        lastSendConnectCommunityId = nil
        if let sendConnectError { throw sendConnectError }
    }

    func fetchIncomingRequests() async throws -> [ConnectionRequest] { incoming }

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
        guard let index = communities.firstIndex(where: { $0.id == communityId }) else { return }
        let community = communities[index]
        communities[index] = Community(
            id: community.id, name: community.name, description: community.description,
            interestTag: community.interestTag, memberCount: community.memberCount,
            coverImageURL: url, createdAt: community.createdAt, creatorId: community.creatorId
        )
    }

    func createCommunity(name: String, description: String, interestTag: String) async throws -> Community {
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

    func deletePost(_ post: ProfilePost) async throws {
        deleteCallCount += 1
        posts.removeAll { $0.id == post.id }
    }
}

final class MockModerationRepository: ModerationRepository, @unchecked Sendable {
    var blockedUserIds: Set<String> = []
    var reportCallCount = 0
    var blockCallCount = 0

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
        blockedUserIds.insert(userId)
    }

    func unblockUser(_ userId: String) async throws {
        blockedUserIds.remove(userId)
    }

    func fetchBlockedUserIds() async throws -> Set<String> {
        blockedUserIds
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
    var updateProfileCallCount = 0
    var lastUpdatedUser: User?

    func fetchProfile(userId: String) async throws -> User {
        if let fetchProfileError { throw fetchProfileError }
        if let profile = profiles[userId] {
            return profile
        }
        throw NSError(domain: "MockUserRepository", code: 404, userInfo: [
            NSLocalizedDescriptionKey: "Profile not found"
        ])
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

    func updateFCMToken(_ token: String) async throws {}

    func clearFCMToken() async throws {}
}
