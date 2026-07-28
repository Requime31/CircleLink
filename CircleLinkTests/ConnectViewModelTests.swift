import Foundation
import Testing
@testable import CircleLink

@MainActor
struct ConnectViewModelTests {
    @Test func acceptCreatesDirectChatAndOpensIt() async {
        let connection = MockConnectionRepository()
        connection.incoming = [
            ConnectionRequest(
                id: "req-1",
                fromUserId: "peer-1",
                toUserId: "user-1",
                communityId: "community-1",
                status: .pending,
                createdAt: Date()
            )
        ]

        let chat = MockChatRepository()
        chat.createDirectChatResult = "chat-peer-1"
        let auth = MockAuthRepository(currentUser: MockAuthRepository.sampleUser)
        var openedChatId: String?

        let viewModel = ConnectViewModel(
            connectionRepository: connection,
            chatRepository: chat,
            communityRepository: MockCommunityRepository(),
            userRepository: MockUserRepository(),
            authRepository: auth,
            onOpenChat: { openedChatId = $0 }
        )

        await viewModel.load()
        await viewModel.accept(requestId: "req-1", fromUserId: "peer-1")

        #expect(connection.acceptCallCount == 1)
        #expect(chat.createDirectChatCallCount == 1)
        #expect(chat.lastCreateDirectPeerId == "peer-1")
        #expect(openedChatId == "chat-peer-1")
    }

    @Test func acceptStillRefreshesMatchedWhenCreateDirectChatFails() async {
        struct Boom: Error, LocalizedError {
            var errorDescription: String? { "Chat create failed" }
        }

        let connection = MockConnectionRepository()
        connection.incoming = [
            ConnectionRequest(
                id: "req-1",
                fromUserId: "peer-1",
                toUserId: "user-1",
                communityId: "community-1",
                status: .pending,
                createdAt: Date()
            )
        ]

        let chat = MockChatRepository()
        chat.createDirectChatError = Boom()
        var openedChatId: String?

        let viewModel = ConnectViewModel(
            connectionRepository: connection,
            chatRepository: chat,
            communityRepository: MockCommunityRepository(),
            userRepository: MockUserRepository(),
            authRepository: MockAuthRepository(currentUser: MockAuthRepository.sampleUser),
            onOpenChat: { openedChatId = $0 }
        )

        await viewModel.load()
        await viewModel.accept(requestId: "req-1", fromUserId: "peer-1")

        #expect(connection.acceptCallCount == 1)
        #expect(openedChatId == nil)
        #expect(viewModel.actionErrorMessage == "Chat create failed")
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
                communityId: "community-1",
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
            onOpenChat: { openedChatId = $0 }
        )

        await viewModel.openChat(with: "peer-1")

        #expect(chat.createDirectChatCallCount == 1)
        #expect(openedChatId == "chat-42")
    }

    @Test func sendConnectWithoutCommunityShowsError() async {
        let connection = MockConnectionRepository()
        let viewModel = ConnectViewModel(
            connectionRepository: connection,
            chatRepository: MockChatRepository(),
            communityRepository: MockCommunityRepository(),
            userRepository: MockUserRepository(),
            authRepository: MockAuthRepository(currentUser: MockAuthRepository.sampleUser),
            onOpenChat: { _ in }
        )

        // Do not call load — selectedCommunityId stays nil.
        await viewModel.sendConnect(to: "peer-1")

        #expect(connection.sendConnectCallCount == 0)
        #expect(viewModel.actionErrorMessage == "Select a community first.")
    }
}
