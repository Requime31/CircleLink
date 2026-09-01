import Foundation
import Testing
@testable import CircleLink

@MainActor
struct OutgoingLikesUITests {
    @Test func outgoingStateCoversLoadingLoadedEmptyAndError() async {
        let connection = MockConnectionRepository()
        connection.outgoingPending = [request()]
        connection.shouldSuspendOutgoingPending = true
        let viewModel = makeViewModel(connection: connection)

        #expect(viewModel.outgoingPendingState == .idle)
        let load = Task { await viewModel.loadOutgoingPending() }
        for _ in 0..<100 where !connection.hasPendingOutgoingPendingFetch { await Task.yield() }
        #expect(viewModel.outgoingPendingState == .loading)
        connection.resumeOutgoingPendingFetch()
        await load.value
        #expect(viewModel.outgoingPendingCount == 1)

        connection.outgoingPending = []
        await viewModel.loadOutgoingPending()
        #expect(viewModel.outgoingPendingState == .empty)

        connection.outgoingPendingError = NSError(
            domain: "test",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Offline"]
        )
        await viewModel.loadOutgoingPending()
        #expect(viewModel.outgoingPendingState == .error("Offline"))
    }

    @Test func badgeReflectsOnlyVisibleOutgoingPendingRows() async {
        let connection = MockConnectionRepository()
        connection.outgoingPending = [request(id: "one", peerID: "peer-1")]
        let viewModel = makeViewModel(connection: connection)

        await viewModel.loadOutgoingPending()

        #expect(viewModel.outgoingPendingCount == 1)
    }

    @Test func peerSelectionRoutesToReadOnlyExistingProfileSheet() {
        let item = OutgoingConnectRequestItem(
            request: request(),
            peer: User(id: "peer-1", displayName: "Taylor")
        )

        let route = PresentedPeer.outgoing(item)

        #expect(route.userId == "peer-1")
        #expect(route.profileMode == .readOnly)
    }

    @Test func quietRefreshKeepsExistingRowsVisible() async {
        let connection = MockConnectionRepository()
        connection.outgoingPending = [request()]
        let viewModel = makeViewModel(connection: connection)
        await viewModel.loadOutgoingPending()

        connection.shouldSuspendOutgoingPending = true
        let refresh = Task { await viewModel.refreshOutgoingPending() }
        for _ in 0..<100 where !connection.hasPendingOutgoingPendingFetch { await Task.yield() }

        #expect(viewModel.outgoingPendingCount == 1)
        connection.resumeOutgoingPendingFetch()
        await refresh.value
        #expect(connection.outgoingPendingFetchCallCount == 2)
    }

    @Test func successfulBlockImmediatelyRemovesOutgoingRow() async {
        let connection = MockConnectionRepository()
        connection.outgoingPending = [request()]
        let moderation = MockModerationRepository()
        let viewModel = makeViewModel(connection: connection, moderation: moderation)
        await viewModel.loadOutgoingPending()

        #expect(await viewModel.block(userId: "peer-1"))
        #expect(viewModel.outgoingPendingState == .empty)
    }

    @Test func readOnlyProfileCannotConnectOrOpenChat() async {
        let connection = MockConnectionRepository()
        let chat = MockChatRepository()
        let users = MockUserRepository()
        users.profiles["peer-1"] = User(id: "peer-1", displayName: "Taylor")
        let viewModel = PeerProfileViewModel(
            userId: "peer-1",
            mode: .readOnly,
            userRepository: users,
            connectionRepository: connection,
            communityRepository: MockCommunityRepository(),
            profilePostRepository: MockProfilePostRepository(),
            chatRepository: chat,
            moderationRepository: MockModerationRepository()
        )

        await viewModel.load()
        await viewModel.connect()
        let chatRoute = await viewModel.openChat()

        #expect(!viewModel.canConnect)
        #expect(connection.sendConnectCallCount == 0)
        #expect(chatRoute == nil)
        #expect(chat.createDirectChatCallCount == 0)
    }

    private func makeViewModel(
        connection: MockConnectionRepository,
        moderation: MockModerationRepository = MockModerationRepository()
    ) -> ConnectViewModel {
        let users = MockUserRepository()
        users.profiles["peer-1"] = User(
            id: "peer-1",
            displayName: "Taylor",
            interests: ["Music"]
        )
        return ConnectViewModel(
            connectionRepository: connection,
            chatRepository: MockChatRepository(),
            communityRepository: MockCommunityRepository(),
            userRepository: users,
            authRepository: MockAuthRepository(currentUser: MockAuthRepository.sampleUser),
            moderationRepository: moderation,
            onOpenChat: { _, _ in }
        )
    }

    private func request(
        id: String = "request-1",
        peerID: String = "peer-1"
    ) -> ConnectionRequest {
        ConnectionRequest(
            id: id,
            fromUserId: "user-1",
            toUserId: peerID,
            communityId: nil,
            status: .pending,
            createdAt: Date()
        )
    }
}
