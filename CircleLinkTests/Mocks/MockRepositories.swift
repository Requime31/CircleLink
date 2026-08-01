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
    var visibleChats: [ChatSummary] = []
    var hiddenChats: [ChatSummary] = []
    var chatInfos: [String: ChatInfo] = [:]
    var messages: [Message] = []
    var sendError: Error?
    var createDirectChatResult: String = "direct-chat-1"
    var createDirectChatError: Error?
    var createGroupChatResult: String = "group_community-1"
    var createGroupChatError: Error?
    var leaveChatError: Error?
    var leaveGroupChatError: Error?
    var createDirectChatCallCount = 0
    var createGroupChatCallCount = 0
    var leaveChatCallCount = 0
    var leaveGroupChatCallCount = 0
    var setMutedCallCount = 0
    var hideChatCallCount = 0
    var unhideChatCallCount = 0
    var lastCreateDirectPeerId: String?
    var lastCreateGroupCommunityId: String?
    var lastLeaveChatId: String?
    var lastLeaveGroupCommunityId: String?
    var lastMutedChatId: String?
    var lastMutedValue: Bool?
    var lastHiddenChatId: String?
    var lastUnhiddenChatId: String?
    var sentClientMessageIds: [String] = []
    var callLog: MockCallLog?
    var liveContinuation: AsyncStream<Message>.Continuation?

    func fetchChats() async throws -> [ChatSummary] { visibleChats }

    func fetchHiddenChats() async throws -> [ChatSummary] { hiddenChats }

    func fetchOrganizedChats() async throws -> OrganizedChats {
        OrganizedChats(visible: visibleChats, hidden: hiddenChats)
    }

    func fetchChatInfo(chatId: String) async throws -> ChatInfo {
        if let info = chatInfos[chatId] {
            return info
        }
        return ChatInfo(
            id: chatId,
            type: .direct,
            title: "Chat",
            communityId: nil,
            participants: [MockAuthRepository.sampleUser]
        )
    }

    func fetchMessages(chatId: String, limit: Int, before: Date?) async throws -> [Message] {
        let filtered: [Message]
        if let before {
            filtered = messages.filter { $0.createdAt < before && $0.chatId == chatId }
        } else {
            filtered = messages.filter { $0.chatId == chatId }
        }
        return Array(filtered.sorted { $0.createdAt > $1.createdAt }.prefix(limit))
            .sorted { $0.createdAt < $1.createdAt }
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

    func leaveChat(chatId: String) async throws {
        leaveChatCallCount += 1
        lastLeaveChatId = chatId
        callLog?.append("leaveChat")
        if let leaveChatError { throw leaveChatError }
        visibleChats.removeAll { $0.id == chatId }
        hiddenChats.removeAll { $0.id == chatId }
    }

    func leaveGroupChat(communityId: String) async throws {
        leaveGroupChatCallCount += 1
        lastLeaveGroupCommunityId = communityId
        callLog?.append("leaveGroupChat")
        if let leaveGroupChatError { throw leaveGroupChatError }
    }

    func setChatMuted(chatId: String, muted: Bool) async throws {
        setMutedCallCount += 1
        lastMutedChatId = chatId
        lastMutedValue = muted
        callLog?.append("setChatMuted")
        if let index = visibleChats.firstIndex(where: { $0.id == chatId }) {
            visibleChats[index].isMuted = muted
        }
        if let index = hiddenChats.firstIndex(where: { $0.id == chatId }) {
            hiddenChats[index].isMuted = muted
        }
    }

    func hideChat(chatId: String) async throws {
        hideChatCallCount += 1
        lastHiddenChatId = chatId
        callLog?.append("hideChat")
        if let index = visibleChats.firstIndex(where: { $0.id == chatId }) {
            let chat = visibleChats.remove(at: index)
            if !hiddenChats.contains(where: { $0.id == chatId }) {
                hiddenChats.append(chat)
            }
        }
    }

    func unhideChat(chatId: String) async throws {
        unhideChatCallCount += 1
        lastUnhiddenChatId = chatId
        callLog?.append("unhideChat")
        if let index = hiddenChats.firstIndex(where: { $0.id == chatId }) {
            let chat = hiddenChats.remove(at: index)
            if !visibleChats.contains(where: { $0.id == chatId }) {
                visibleChats.append(chat)
            }
        }
    }
}

// MARK: - Connection

final class MockConnectionRepository: ConnectionRepository, @unchecked Sendable {
    var candidates: [User] = []
    var incoming: [ConnectionRequest] = []
    var matched: [ConnectionRequest] = []
    /// Extra / overridden peer relationships keyed by peer user id.
    var connectionsByPeerId: [String: ConnectionRequest] = [:]
    var respondError: Error?
    var sendConnectError: Error?
    var fetchConnectionError: Error?
    var removeConnectionError: Error?
    var acceptCallCount = 0
    var declineCallCount = 0
    var sendConnectCallCount = 0
    var removeConnectionCallCount = 0
    var lastSendConnectUserId: String?
    var lastSendConnectCommunityId: String?
    var lastRemovedPeerId: String?

    func fetchCandidates(communityId: String) async throws -> [User] { candidates }

    func sendConnect(to userId: String, in communityId: String) async throws {
        sendConnectCallCount += 1
        lastSendConnectUserId = userId
        lastSendConnectCommunityId = communityId
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
        if let fetchConnectionError { throw fetchConnectionError }
        if let override = connectionsByPeerId[peerId] {
            return override
        }
        let currentUserId = MockAuthRepository.sampleUser.id
        return matched.first {
            ($0.fromUserId == currentUserId && $0.toUserId == peerId)
                || ($0.toUserId == currentUserId && $0.fromUserId == peerId)
        } ?? incoming.first {
            ($0.fromUserId == currentUserId && $0.toUserId == peerId)
                || ($0.toUserId == currentUserId && $0.fromUserId == peerId)
        }
    }

    func removeConnection(with peerId: String) async throws {
        removeConnectionCallCount += 1
        lastRemovedPeerId = peerId
        if let removeConnectionError { throw removeConnectionError }
        let currentUserId = MockAuthRepository.sampleUser.id
        for index in matched.indices {
            let request = matched[index]
            let isPair =
                (request.fromUserId == currentUserId && request.toUserId == peerId)
                || (request.toUserId == currentUserId && request.fromUserId == peerId)
            if isPair {
                matched[index].status = .declined
            }
        }
        connectionsByPeerId[peerId]?.status = .declined
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
    var createCommunityError: Error?
    var joinCallCount = 0
    var leaveCallCount = 0
    var createCommunityCallCount = 0
    var lastJoinedCommunityId: String?
    var lastLeftCommunityId: String?
    var lastCreatedCommunity: Community?
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

    func createCommunity(
        name: String,
        description: String,
        interestTag: String
    ) async throws -> Community {
        createCommunityCallCount += 1
        callLog?.append("community.create")
        if let createCommunityError { throw createCommunityError }
        let community = Community(
            id: "community-\(communities.count + 1)",
            name: name,
            description: description,
            interestTag: interestTag,
            memberCount: 1
        )
        communities.append(community)
        membersByCommunity[community.id] = [MockAuthRepository.sampleUser]
        lastCreatedCommunity = community
        return community
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

    func fetchProfiles(userIds: [String]) async throws -> [String: User] {
        if let fetchProfileError { throw fetchProfileError }
        var result: [String: User] = [:]
        for id in Set(userIds) where !id.isEmpty {
            if let profile = profiles[id] {
                result[id] = profile
            }
        }
        return result
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
