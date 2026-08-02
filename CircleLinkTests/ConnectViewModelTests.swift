import Foundation
import Testing
@testable import CircleLink

@MainActor
struct ConnectViewModelTests {
    private func makeViewModel(
        connection: MockConnectionRepository = MockConnectionRepository(),
        chat: MockChatRepository = MockChatRepository(),
        user: MockUserRepository = MockUserRepository(),
        moderation: StubModerationRepository = StubModerationRepository(),
        onOpenChat: @escaping (String) -> Void = { _ in }
    ) -> ConnectViewModel {
        ConnectViewModel(
            connectionRepository: connection,
            chatRepository: chat,
            communityRepository: MockCommunityRepository(),
            userRepository: user,
            authRepository: MockAuthRepository(currentUser: MockAuthRepository.sampleUser),
            moderationRepository: moderation,
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

        let viewModel = makeViewModel(connection: connection, chat: chat) { openedChatId = $0 }

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

    @Test func acceptSurfacesRepositoryError() async {
        struct Boom: Error, LocalizedError {
            var errorDescription: String? { "Accept failed" }
        }

        let connection = MockConnectionRepository()
        connection.incoming = [pendingRequest()]
        connection.respondError = Boom()

        let viewModel = makeViewModel(connection: connection)

        await viewModel.load()
        await viewModel.accept(requestId: "req-1", fromUserId: "peer-1")

        #expect(connection.acceptCallCount == 0)
        #expect(viewModel.actionErrorMessage == "Accept failed")
    }

    @Test func declineRemovesIncomingRequest() async {
        let connection = MockConnectionRepository()
        connection.incoming = [pendingRequest(id: "req-2")]

        let viewModel = makeViewModel(connection: connection)

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

    @Test func openChatWithPeerCreatesDirectChat() async {
        let chat = MockChatRepository()
        chat.createDirectChatResult = "chat-42"
        var openedChatId: String?

        let viewModel = makeViewModel(chat: chat) { openedChatId = $0 }

        await viewModel.openChat(with: "peer-1")

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

        let viewModel = makeViewModel(connection: connection)
        await viewModel.load()
        await viewModel.selectCommunity("community-1")

        #expect(viewModel.deckCandidates.contains { $0.id == "peer-1" })

        viewModel.passCandidate(userId: "peer-1")

        #expect(!viewModel.deckCandidates.contains { $0.id == "peer-1" })
    }

    @Test func loadIncomingBatchesPeerProfiles() async {
        let connection = MockConnectionRepository()
        connection.incoming = [
            pendingRequest(id: "req-1", fromUserId: "peer-1"),
            pendingRequest(id: "req-2", fromUserId: "peer-2")
        ]

        let user = MockUserRepository()
        user.profiles["peer-2"] = samplePeer(id: "peer-2", name: "Peer Two")

        let viewModel = makeViewModel(connection: connection, user: user)
        await viewModel.load()

        #expect(user.fetchProfilesCallCount == 1)
        #expect(user.fetchProfileCallCount == 0)
        #expect(Set(user.lastFetchProfilesUserIds) == Set(["peer-1", "peer-2"]))

        if case let .loaded(items) = viewModel.incomingState {
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

        let viewModel = makeViewModel(
            connection: connection,
            user: user,
            moderation: StubModerationRepository(blockedUserIds: ["blocked-peer"])
        )
        await viewModel.load()

        #expect(user.fetchProfilesCallCount == 1)
        #expect(user.fetchProfileCallCount == 0)
        #expect(Set(user.lastFetchProfilesUserIds) == Set(["peer-1", "peer-2"]))
        #expect(!user.lastFetchProfilesUserIds.contains("blocked-peer"))

        if case let .loaded(items) = viewModel.matchedState {
            #expect(items.map(\.request.id).sorted() == ["m-1", "m-2"])
        } else {
            Issue.record("Expected matched list without blocked peer")
        }
    }
}
