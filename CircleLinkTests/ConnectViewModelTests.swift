import Foundation
import Testing
@testable import CircleLink

@MainActor
struct ConnectViewModelTests {
    private func makeBlockFilter(
        moderation: StubModerationRepository = StubModerationRepository()
    ) -> ConnectBlockFilter {
        ConnectBlockFilter(moderationRepository: moderation)
    }

    private func makeTab(
        connection: MockConnectionRepository = MockConnectionRepository(),
        chat: MockChatRepository = MockChatRepository(),
        user: MockUserRepository = MockUserRepository(),
        moderation: StubModerationRepository = StubModerationRepository(),
        onOpenChat: @escaping (String) -> Void = { _ in }
    ) -> ConnectTabModel {
        ConnectTabModel(
            connectionRepository: connection,
            chatRepository: chat,
            communityRepository: MockCommunityRepository(),
            userRepository: user,
            authRepository: MockAuthRepository(currentUser: MockAuthRepository.sampleUser),
            moderationRepository: moderation,
            onOpenChat: onOpenChat
        )
    }

    private func makeDiscovery(
        connection: MockConnectionRepository = MockConnectionRepository(),
        moderation: StubModerationRepository = StubModerationRepository()
    ) async -> ConnectDiscoveryViewModel {
        let filter = makeBlockFilter(moderation: moderation)
        await filter.refresh()
        return ConnectDiscoveryViewModel(
            connectionRepository: connection,
            communityRepository: MockCommunityRepository(),
            blockFilter: filter
        )
    }

    private func makeInbox(
        connection: MockConnectionRepository = MockConnectionRepository(),
        user: MockUserRepository = MockUserRepository(),
        moderation: StubModerationRepository = StubModerationRepository()
    ) async -> ConnectionInboxViewModel {
        let filter = makeBlockFilter(moderation: moderation)
        await filter.refresh()
        return ConnectionInboxViewModel(
            connectionRepository: connection,
            userRepository: user,
            blockFilter: filter
        )
    }

    private func makeMatches(
        connection: MockConnectionRepository = MockConnectionRepository(),
        chat: MockChatRepository = MockChatRepository(),
        user: MockUserRepository = MockUserRepository(),
        moderation: StubModerationRepository = StubModerationRepository(),
        onOpenChat: @escaping (String) -> Void = { _ in }
    ) async -> MatchesViewModel {
        let filter = makeBlockFilter(moderation: moderation)
        await filter.refresh()
        return MatchesViewModel(
            connectionRepository: connection,
            chatRepository: chat,
            userRepository: user,
            authRepository: MockAuthRepository(currentUser: MockAuthRepository.sampleUser),
            blockFilter: filter,
            onOpenChat: onOpenChat
        )
    }

    private func samplePeer(id: String, name: String) -> User {
        User(
            id: id,
            displayName: name,
            avatarURL: nil,
            avatarBase64: nil,
            interests: ["Design"],
            ageConfirmedAt: Date()
        )
    }

    private func pendingRequest(id: String = "req-1", fromUserId: String = "peer-1") -> ConnectionRequest {
        ConnectionRequest(
            id: id,
            fromUserId: fromUserId,
            toUserId: "user-1",
            communityId: "community-1",
            status: .pending,
            createdAt: Date()
        )
    }

    /// Accept only moves the request into Matches — chat opens later via `openChat`.
    @Test func acceptMovesRequestToMatchedWithoutOpeningChat() async {
        let connection = MockConnectionRepository()
        connection.incoming = [pendingRequest()]
        let chat = MockChatRepository()
        var openedChatId: String?

        let tab = makeTab(connection: connection, chat: chat) { openedChatId = $0 }

        await tab.load()
        await tab.inbox.accept(requestId: "req-1", fromUserId: "peer-1")

        #expect(connection.acceptCallCount == 1)
        #expect(chat.createDirectChatCallCount == 0)
        #expect(openedChatId == nil)
        if case let .loaded(matched) = tab.matches.matchedState {
            #expect(matched.contains { $0.request.id == "req-1" })
        } else {
            Issue.record("Expected matched list after accept")
        }
    }

    @Test func acceptSurfacesRepositoryError() async {
        struct Boom: Error, LocalizedError {
            var errorDescription: String? { "Accept failed" }
        }

        let connection = MockConnectionRepository()
        connection.incoming = [pendingRequest()]
        connection.respondError = Boom()

        let inbox = await makeInbox(connection: connection)

        await inbox.load()
        await inbox.accept(requestId: "req-1", fromUserId: "peer-1")

        #expect(connection.acceptCallCount == 0)
        #expect(inbox.actionErrorMessage == "Accept failed")
    }

    @Test func declineRemovesIncomingRequest() async {
        let connection = MockConnectionRepository()
        connection.incoming = [pendingRequest(id: "req-2")]

        let inbox = await makeInbox(connection: connection)

        await inbox.load()
        await inbox.decline(requestId: "req-2")

        #expect(connection.declineCallCount == 1)
        if case .empty = inbox.incomingState {
            // ok
        } else if case let .loaded(items) = inbox.incomingState {
            #expect(!items.contains { $0.id == "req-2" })
        } else {
            Issue.record("Expected empty or filtered incoming after decline")
        }
    }

    @Test func openChatWithPeerCreatesDirectChat() async {
        let chat = MockChatRepository()
        chat.createDirectChatResult = "chat-42"
        var openedChatId: String?

        let matches = await makeMatches(chat: chat) { openedChatId = $0 }

        await matches.openChat(with: "peer-1")

        #expect(chat.createDirectChatCallCount == 1)
        #expect(openedChatId == "chat-42")
    }

    @Test func passCandidateHidesUserFromDeck() async {
        let connection = MockConnectionRepository()
        connection.candidates = [
            User(
                id: "peer-1",
                displayName: "Peer",
                avatarURL: nil,
                avatarBase64: nil,
                interests: ["Design"],
                ageConfirmedAt: Date()
            )
        ]

        let discovery = await makeDiscovery(connection: connection)
        await discovery.load()
        await discovery.selectCommunity("community-1")

        #expect(discovery.deckCandidates.contains { $0.id == "peer-1" })

        discovery.passCandidate(userId: "peer-1")

        #expect(!discovery.deckCandidates.contains { $0.id == "peer-1" })
    }

    @Test func loadIncomingBatchesPeerProfiles() async {
        let connection = MockConnectionRepository()
        connection.incoming = [
            pendingRequest(id: "req-1", fromUserId: "peer-1"),
            pendingRequest(id: "req-2", fromUserId: "peer-2")
        ]

        let user = MockUserRepository()
        user.profiles["peer-2"] = samplePeer(id: "peer-2", name: "Peer Two")

        let inbox = await makeInbox(connection: connection, user: user)
        await inbox.load()

        #expect(user.fetchProfilesCallCount == 1)
        #expect(user.fetchProfileCallCount == 0)
        #expect(Set(user.lastFetchProfilesUserIds) == Set(["peer-1", "peer-2"]))

        if case let .loaded(items) = inbox.incomingState {
            #expect(items.map(\.peer.id).sorted() == ["peer-1", "peer-2"])
        } else {
            Issue.record("Expected loaded incoming with both peers")
        }
    }

    @Test func loadMatchedBatchesPeerProfilesAndSkipsBlocked() async {
        let connection = MockConnectionRepository()
        connection.matched = [
            ConnectionRequest(
                id: "m-1",
                fromUserId: "peer-1",
                toUserId: "user-1",
                communityId: "community-1",
                status: .accepted,
                createdAt: Date()
            ),
            ConnectionRequest(
                id: "m-2",
                fromUserId: "user-1",
                toUserId: "peer-2",
                communityId: "community-1",
                status: .accepted,
                createdAt: Date()
            ),
            ConnectionRequest(
                id: "m-3",
                fromUserId: "blocked-peer",
                toUserId: "user-1",
                communityId: "community-1",
                status: .accepted,
                createdAt: Date()
            )
        ]

        let user = MockUserRepository()
        user.profiles["peer-2"] = samplePeer(id: "peer-2", name: "Peer Two")
        user.profiles["blocked-peer"] = samplePeer(id: "blocked-peer", name: "Blocked")

        let matches = await makeMatches(
            connection: connection,
            user: user,
            moderation: StubModerationRepository(blockedUserIds: ["blocked-peer"])
        )
        await matches.load()

        #expect(user.fetchProfilesCallCount == 1)
        #expect(user.fetchProfileCallCount == 0)
        #expect(Set(user.lastFetchProfilesUserIds) == Set(["peer-1", "peer-2"]))
        #expect(!user.lastFetchProfilesUserIds.contains("blocked-peer"))

        if case let .loaded(items) = matches.matchedState {
            #expect(items.map(\.request.id).sorted() == ["m-1", "m-2"])
        } else {
            Issue.record("Expected matched list without blocked peer")
        }
    }

    @Test func blockedUsersFailureSurfacesDegradedStateWithoutFailingDashboard() async {
        struct BlockedUsersError: LocalizedError {
            var errorDescription: String? { "Block list unavailable" }
        }

        let connection = MockConnectionRepository()
        let moderation = StubModerationRepository()
        moderation.fetchBlockedUserIdsError = BlockedUsersError()
        let tab = makeTab(connection: connection, moderation: moderation)

        await tab.load()

        #expect(tab.blockedUsersErrorMessage == "Block list unavailable")
        #expect(connection.fetchIncomingCallCount == 1)

        moderation.fetchBlockedUserIdsError = nil
        await tab.load()

        #expect(tab.blockedUsersErrorMessage == nil)
    }

    @Test func overlappingDashboardLoadKeepsLatestState() async {
        let connection = MockConnectionRepository()
        connection.incoming = [pendingRequest(id: "req-old")]
        let community = MockCommunityRepository()
        community.shouldHoldCommunities = true

        let tab = ConnectTabModel(
            connectionRepository: connection,
            chatRepository: MockChatRepository(),
            communityRepository: community,
            userRepository: MockUserRepository(),
            authRepository: MockAuthRepository(currentUser: MockAuthRepository.sampleUser),
            moderationRepository: StubModerationRepository(),
            onOpenChat: { _ in }
        )

        let first = Task { await tab.load() }
        await waitUntil { community.isHoldingCommunities }

        community.shouldHoldCommunities = false
        connection.incoming = [pendingRequest(id: "req-new", fromUserId: "peer-2")]
        let second = Task { await tab.load() }
        await Task.yield()
        community.releaseCommunitiesHold()
        await first.value
        await second.value

        #expect(connection.fetchIncomingCallCount >= 2)
        if case let .loaded(items) = tab.inbox.incomingState {
            #expect(items.map(\.request.id) == ["req-new"])
        } else {
            Issue.record("Expected latest inbox after overlapping loads")
        }
    }

    @Test func acceptIgnoresDuplicateWhileInFlight() async {
        let connection = MockConnectionRepository()
        connection.incoming = [pendingRequest()]
        connection.shouldHoldRespond = true
        let inbox = await makeInbox(connection: connection)
        await inbox.load()

        let first = Task { await inbox.accept(requestId: "req-1", fromUserId: "peer-1") }
        await waitUntil { connection.isHoldingRespond }

        await inbox.accept(requestId: "req-1", fromUserId: "peer-1")
        #expect(connection.acceptCallCount == 0)

        connection.releaseRespondHold()
        await first.value

        #expect(connection.acceptCallCount == 1)
        #expect(inbox.respondingRequestId == nil)
    }

    @Test func openChatIgnoresDuplicateWhileInFlight() async {
        let chat = MockChatRepository()
        chat.createDirectChatResult = "chat-42"
        chat.shouldHoldCreateDirect = true
        var opened: [String] = []

        let matches = await makeMatches(chat: chat) { opened.append($0) }
        let first = Task { await matches.openChat(with: "peer-1") }
        await waitUntil { chat.isHoldingCreateDirect }

        await matches.openChat(with: "peer-1")
        #expect(chat.createDirectChatCallCount == 1)

        chat.releaseCreateDirectHold()
        await first.value

        #expect(chat.createDirectChatCallCount == 1)
        #expect(opened == ["chat-42"])
        #expect(matches.openingChatPeerId == nil)
    }

    private func waitUntil(_ condition: @MainActor () -> Bool) async {
        for _ in 0..<200 {
            if condition() { return }
            await Task.yield()
        }
    }
}
