import Foundation
import Testing
@testable import CircleLink

@MainActor
struct ConnectViewModelTests {
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
            onOpenChat: { openedChatId = $0 }
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
            onOpenChat: { _ in }
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

    @Test func openChatWithPeerCreatesDirectChat() async {
        let chat = MockChatRepository()
        chat.createDirectChatResult = "chat-42"
        var openedChatId: String?

        let viewModel = ConnectViewModel(
            connectionRepository: MockConnectionRepository(),
            chatRepository: chat,
            communityRepository: MockCommunityRepository(),
            userRepository: MockUserRepository(),
            authRepository: MockAuthRepository(currentUser: MockAuthRepository.sampleUser),
            moderationRepository: MockModerationRepository(),
            onOpenChat: { openedChatId = $0 }
        )

        await viewModel.openChat(with: "peer-1")

        #expect(chat.createDirectChatCallCount == 1)
        #expect(openedChatId == "chat-42")
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
            onOpenChat: { _ in }
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
            onOpenChat: { _ in }
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
            onOpenChat: { _ in }
        )

        await viewModel.load()
        viewModel.passCandidate(userId: "peer-1")
        #expect(viewModel.topCandidate == nil)
        #expect(viewModel.canUndoPass)

        viewModel.undoLastPass()
        #expect(viewModel.topCandidate?.id == "peer-1")
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
