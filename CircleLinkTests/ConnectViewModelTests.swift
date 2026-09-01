import Foundation
import Testing
@testable import CircleLink

@MainActor
struct ConnectViewModelTests {
    @Test func blockImmediatelyRemovesPeerFromEveryConnectCollection() async {
        let connection = MockConnectionRepository()
        let peer = User(id: "peer-1", displayName: "Peer")
        connection.candidates = [peer]
        connection.incoming = [
            ConnectionRequest(id: "incoming", fromUserId: peer.id, toUserId: "user-1", communityId: nil, status: .pending, createdAt: Date())
        ]
        connection.matched = [
            ConnectionRequest(id: "matched", fromUserId: "user-1", toUserId: peer.id, communityId: nil, status: .accepted, createdAt: Date())
        ]
        let users = MockUserRepository()
        users.profiles[peer.id] = peer
        let moderation = MockModerationRepository()
        let viewModel = ConnectViewModel(
            connectionRepository: connection,
            chatRepository: MockChatRepository(),
            communityRepository: MockCommunityRepository(),
            userRepository: users,
            authRepository: MockAuthRepository(currentUser: MockAuthRepository.sampleUser),
            moderationRepository: moderation,
            onOpenChat: { _, _ in }
        )

        await viewModel.load()
        let succeeded = await viewModel.block(userId: peer.id)

        #expect(succeeded)
        #expect(viewModel.topCandidate == nil)
        #expect(viewModel.incomingCount == 0)
        #expect(viewModel.matchedCount == 0)
    }

    @Test func blockFailureCanRetryWithoutClosingFlow() async {
        let moderation = MockModerationRepository()
        moderation.blockError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Offline"])
        let viewModel = makeBlockingViewModel(moderation: moderation)

        #expect(await viewModel.block(userId: "peer-1") == false)
        #expect(viewModel.blockErrorMessage == "Offline")

        moderation.blockError = nil
        #expect(await viewModel.block(userId: "peer-1"))
        #expect(moderation.blockCallCount == 2)
    }

    @Test func blockRejectsDoubleTapAndIgnoresResultAfterSessionReset() async {
        let moderation = MockModerationRepository()
        moderation.shouldSuspendBlock = true
        let viewModel = makeBlockingViewModel(moderation: moderation)

        let first = Task { await viewModel.block(userId: "peer-1") }
        await Task.yield()
        let second = await viewModel.block(userId: "peer-1")
        #expect(second == false)
        #expect(moderation.blockCallCount == 1)

        viewModel.resetForm()
        moderation.resumeBlock()
        #expect(await first.value == false)
        #expect(viewModel.moderationMessage == nil)
    }

    @Test func acceptRefreshesIncomingAndMatchedWithoutOpeningChat() async {
        let connection = MockConnectionRepository()
        connection.incoming = [
            ConnectionRequest(
                id: "req-1",
                fromUserId: "peer-1",
                toUserId: "user-1",
                communityId: nil,
                status: .pending,
                createdAt: Date()
            )
        ]

        let chat = MockChatRepository()
        var openedChatId: String?

        let viewModel = ConnectViewModel(
            connectionRepository: connection,
            chatRepository: chat,
            communityRepository: MockCommunityRepository(),
            userRepository: MockUserRepository(),
            authRepository: MockAuthRepository(currentUser: MockAuthRepository.sampleUser),
            moderationRepository: MockModerationRepository(),
            onOpenChat: { chatId, _ in openedChatId = chatId }
        )

        await viewModel.load()
        await viewModel.accept(requestId: "req-1", fromUserId: "peer-1")

        #expect(connection.acceptCallCount == 1)
        #expect(chat.createDirectChatCallCount == 0)
        #expect(openedChatId == nil)
        if case let .loaded(matched) = viewModel.matchedState {
            #expect(matched.contains { $0.request.id == "req-1" })
        } else {
            Issue.record("Expected matched list after accept")
        }
    }

    @Test func declineRemovesIncomingRequest() async {
        let connection = MockConnectionRepository()
        connection.incoming = [
            ConnectionRequest(
                id: "req-2",
                fromUserId: "peer-1",
                toUserId: "user-1",
                communityId: nil,
                status: .pending,
                createdAt: Date()
            )
        ]

        let viewModel = ConnectViewModel(
            connectionRepository: connection,
            chatRepository: MockChatRepository(),
            communityRepository: MockCommunityRepository(),
            userRepository: MockUserRepository(),
            authRepository: MockAuthRepository(currentUser: MockAuthRepository.sampleUser),
            moderationRepository: MockModerationRepository(),
            onOpenChat: { _, _ in }
        )

        await viewModel.load()
        await viewModel.decline(requestId: "req-2")

        #expect(connection.declineCallCount == 1)
        if case .empty = viewModel.incomingState {
            // ok
        } else if case let .loaded(items) = viewModel.incomingState {
            #expect(!items.contains { $0.id == "req-2" })
        } else {
            Issue.record("Expected empty or filtered incoming after decline")
        }
    }

    @Test func matchedPeersWithSharedCommunitiesOpenDirectRoute() async {
        let peer = User(id: "peer-1", displayName: "Taylor")
        let connection = MockConnectionRepository()
        connection.matched = [
            ConnectionRequest(
                id: "match-1",
                fromUserId: "user-1",
                toUserId: peer.id,
                communityId: "community-1",
                status: .accepted,
                createdAt: Date()
            )
        ]
        let chat = MockChatRepository()
        chat.createDirectChatResult = "peer-1_user-1"
        let communities = MockCommunityRepository()
        communities.communitiesForUser = [
            "user-1": communities.communities,
            peer.id: communities.communities
        ]
        let users = MockUserRepository()
        users.profiles[peer.id] = peer
        var route: ChatThreadRoute?

        let viewModel = ConnectViewModel(
            connectionRepository: connection,
            chatRepository: chat,
            communityRepository: communities,
            userRepository: users,
            authRepository: MockAuthRepository(currentUser: MockAuthRepository.sampleUser),
            moderationRepository: MockModerationRepository(),
            onOpenChat: { chatId, title in
                route = .direct(chatId: chatId, title: title)
            }
        )

        await viewModel.load()
        await viewModel.openChat(with: peer.id)

        #expect(chat.createDirectChatCallCount == 1)
        #expect(chat.lastCreateDirectPeerId == peer.id)
        #expect(chat.createGroupChatCallCount == 0)
        #expect(route?.chatId == "peer-1_user-1")
        #expect(route?.title == "Taylor")
        #expect(route?.communityId == nil)
        #expect(route?.chatId != "group_community-1")
    }

    @Test func directChatRepositoryErrorDoesNotNavigate() async {
        let chat = MockChatRepository()
        chat.createDirectChatError = NSError(
            domain: "test",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Offline"]
        )
        var didNavigate = false
        let viewModel = ConnectViewModel(
            connectionRepository: MockConnectionRepository(),
            chatRepository: chat,
            communityRepository: MockCommunityRepository(),
            userRepository: MockUserRepository(),
            authRepository: MockAuthRepository(currentUser: MockAuthRepository.sampleUser),
            moderationRepository: MockModerationRepository(),
            onOpenChat: { _, _ in didNavigate = true }
        )

        await viewModel.openChat(with: "peer-1")

        #expect(chat.createDirectChatCallCount == 1)
        #expect(!didNavigate)
        #expect(viewModel.actionErrorMessage == "Offline")
    }

    @Test func loadRanksCandidatesBySharedInterests() async {
        let connection = MockConnectionRepository()
        connection.candidates = [
            User(id: "a", displayName: "No overlap", interests: ["Cooking"]),
            User(id: "b", displayName: "Two matches", interests: ["Sports", "Music", "Travel"]),
            User(id: "c", displayName: "One match", interests: ["Music", "Chess"])
        ]

        let me = User(
            id: "user-1",
            displayName: "Test User",
            interests: ["Sports", "Music", "Art"],
            ageConfirmedAt: Date()
        )
        let users = MockUserRepository()
        users.profiles = [me.id: me]

        let viewModel = ConnectViewModel(
            connectionRepository: connection,
            chatRepository: MockChatRepository(),
            communityRepository: MockCommunityRepository(),
            userRepository: users,
            authRepository: MockAuthRepository(currentUser: me),
            moderationRepository: MockModerationRepository(),
            onOpenChat: { _, _ in }
        )

        await viewModel.load()

        guard case let .loaded(ranked) = viewModel.candidatesState else {
            Issue.record("Expected loaded candidates")
            return
        }
        #expect(ranked.map(\.id) == ["b", "c", "a"])
    }

    @Test func sayHiSendsConnectAndRemovesFromDeck() async {
        let connection = MockConnectionRepository()
        connection.candidates = [
            User(id: "peer-1", displayName: "Peer", interests: ["Music"])
        ]

        let viewModel = ConnectViewModel(
            connectionRepository: connection,
            chatRepository: MockChatRepository(),
            communityRepository: MockCommunityRepository(),
            userRepository: MockUserRepository(),
            authRepository: MockAuthRepository(currentUser: MockAuthRepository.sampleUser),
            moderationRepository: MockModerationRepository(),
            onOpenChat: { _, _ in }
        )

        await viewModel.load()
        await viewModel.sayHiAndWait(to: "peer-1")

        #expect(connection.sendConnectCallCount == 1)
        #expect(connection.lastSendConnectUserId == "peer-1")
        #expect(viewModel.topCandidate?.id != "peer-1")
    }

    @Test func passAndUndoRestoreCandidate() async {
        let connection = MockConnectionRepository()
        connection.candidates = [
            User(id: "peer-1", displayName: "Peer", interests: ["Music"])
        ]

        let viewModel = ConnectViewModel(
            connectionRepository: connection,
            chatRepository: MockChatRepository(),
            communityRepository: MockCommunityRepository(),
            userRepository: MockUserRepository(),
            authRepository: MockAuthRepository(currentUser: MockAuthRepository.sampleUser),
            moderationRepository: MockModerationRepository(),
            onOpenChat: { _, _ in }
        )

        await viewModel.load()
        viewModel.passCandidate(userId: "peer-1")
        #expect(viewModel.topCandidate == nil)
        #expect(viewModel.canUndoPass)

        viewModel.undoLastPass()
        #expect(viewModel.topCandidate?.id == "peer-1")
    }

    @Test func passedCandidateStaysRemovedAcrossChangingRefreshResults() async {
        let connection = MockConnectionRepository()
        let passedPeer = User(id: "peer-1", displayName: "Passed peer")
        let remainingPeer = User(id: "peer-2", displayName: "Remaining peer")
        connection.candidates = [passedPeer, remainingPeer]

        let viewModel = ConnectViewModel(
            connectionRepository: connection,
            chatRepository: MockChatRepository(),
            communityRepository: MockCommunityRepository(),
            userRepository: MockUserRepository(),
            authRepository: MockAuthRepository(currentUser: MockAuthRepository.sampleUser),
            moderationRepository: MockModerationRepository(),
            onOpenChat: { _, _ in }
        )

        await viewModel.load()
        viewModel.passCandidate(userId: passedPeer.id)

        connection.candidates = [remainingPeer]
        await viewModel.refreshQuietly()
        connection.candidates = [passedPeer, remainingPeer]
        await viewModel.refreshQuietly()

        #expect(viewModel.deckCandidates.map(\.id) == [remainingPeer.id])
        #expect(viewModel.passedCandidateIds.contains(passedPeer.id))
        #expect(viewModel.canUndoPass)
    }

    @Test func loadFiltersDeactivatedCandidatesIncomingAndMatches() async {
        let connection = MockConnectionRepository()
        let deactivated = User(
            id: "peer-1",
            displayName: "Unavailable",
            interests: ["Music"],
            accountState: .deactivated,
            deletionRequestedAt: Date(),
            scheduledDeletionAt: Date().addingTimeInterval(30 * 86_400)
        )
        connection.candidates = [deactivated]
        connection.incoming = [
            ConnectionRequest(
                id: "incoming", fromUserId: deactivated.id, toUserId: "user-1",
                communityId: nil, status: .pending, createdAt: Date()
            )
        ]
        connection.matched = [
            ConnectionRequest(
                id: "matched", fromUserId: "user-1", toUserId: deactivated.id,
                communityId: nil, status: .accepted, createdAt: Date()
            )
        ]
        let users = MockUserRepository()
        users.profiles[deactivated.id] = deactivated
        let viewModel = ConnectViewModel(
            connectionRepository: connection,
            chatRepository: MockChatRepository(),
            communityRepository: MockCommunityRepository(),
            userRepository: users,
            authRepository: MockAuthRepository(currentUser: MockAuthRepository.sampleUser),
            moderationRepository: MockModerationRepository(),
            onOpenChat: { _, _ in }
        )

        await viewModel.load()

        if case .empty = viewModel.candidatesState {} else { Issue.record("Expected no candidates") }
        if case .empty = viewModel.incomingState {} else { Issue.record("Expected no incoming requests") }
        if case .empty = viewModel.matchedState {} else { Issue.record("Expected no matches") }
    }

    @Test func newConnectAndDirectChatRejectDeactivatedPeer() async {
        let connection = MockConnectionRepository()
        connection.deactivatedPeerIds = ["peer-1"]
        let chat = MockChatRepository()
        chat.deactivatedPeerIds = ["peer-1"]
        let viewModel = ConnectViewModel(
            connectionRepository: connection,
            chatRepository: chat,
            communityRepository: MockCommunityRepository(),
            userRepository: MockUserRepository(),
            authRepository: MockAuthRepository(currentUser: MockAuthRepository.sampleUser),
            moderationRepository: MockModerationRepository(),
            onOpenChat: { _, _ in }
        )

        await viewModel.sayHiAndWait(to: "peer-1")
        #expect(viewModel.actionErrorMessage != nil)
        await viewModel.openChat(with: "peer-1")
        #expect(viewModel.actionErrorMessage != nil)
        #expect(connection.sendConnectCallCount == 1)
        #expect(chat.createDirectChatCallCount == 1)
    }
}

private extension ConnectViewModelTests {
    func makeBlockingViewModel(moderation: MockModerationRepository) -> ConnectViewModel {
        ConnectViewModel(
            connectionRepository: MockConnectionRepository(),
            chatRepository: MockChatRepository(),
            communityRepository: MockCommunityRepository(),
            userRepository: MockUserRepository(),
            authRepository: MockAuthRepository(currentUser: MockAuthRepository.sampleUser),
            moderationRepository: moderation,
            onOpenChat: { _, _ in }
        )
    }
}

@Suite
struct ConnectCandidateRankerTests {
    @Test func sharedInterestsSortFirst() {
        let mine = ["Music", "Art"]
        let ranked = ConnectCandidateRanker.ranked(
            [
                User(id: "1", displayName: "Zed", interests: ["Chess"]),
                User(id: "2", displayName: "Ann", interests: ["Music", "Art"]),
                User(id: "3", displayName: "Bob", interests: ["Music"])
            ],
            matching: mine
        )
        #expect(ranked.map(\.id) == ["2", "3", "1"])
    }
}
