import Foundation
import Testing
@testable import CircleLink

@MainActor
struct PeerProfileViewModelTests {
    @Test func likedYouLikeAcceptsAndCompletes() async {
        let connections = MockConnectionRepository()
        connections.incoming = [
            ConnectionRequest(
                id: "req-1",
                fromUserId: "peer-1",
                toUserId: "user-1",
                communityId: nil,
                status: .pending,
                createdAt: Date()
            )
        ]

        let viewModel = makeViewModel(
            mode: .likedYou(requestId: "req-1"),
            connectionRepository: connections
        )

        await viewModel.load()
        await viewModel.like()

        #expect(connections.acceptCallCount == 1)
        #expect(viewModel.didCompleteAction == true)
        #expect(viewModel.actionErrorMessage == nil)
    }

    @Test func likedYouSkipDeclinesAndCompletes() async {
        let connections = MockConnectionRepository()
        connections.incoming = [
            ConnectionRequest(
                id: "req-1",
                fromUserId: "peer-1",
                toUserId: "user-1",
                communityId: nil,
                status: .pending,
                createdAt: Date()
            )
        ]

        let viewModel = makeViewModel(
            mode: .likedYou(requestId: "req-1"),
            connectionRepository: connections
        )

        await viewModel.load()
        await viewModel.skip()

        #expect(connections.declineCallCount == 1)
        #expect(viewModel.didCompleteAction == true)
        #expect(viewModel.actionErrorMessage == nil)
    }

    @Test func likedYouLikeFailureKeepsSheetOpen() async {
        let connections = MockConnectionRepository()
        connections.respondError = NSError(
            domain: "test",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Network down"]
        )

        let viewModel = makeViewModel(
            mode: .likedYou(requestId: "req-1"),
            connectionRepository: connections
        )

        await viewModel.load()
        await viewModel.like()

        #expect(viewModel.didCompleteAction == false)
        #expect(viewModel.actionErrorMessage == "Network down")
    }

    @Test func socialLoadSetsMatchedRelationship() async {
        let connections = MockConnectionRepository()
        connections.matched = [
            ConnectionRequest(
                id: "a_b",
                fromUserId: "user-1",
                toUserId: "peer-1",
                communityId: nil,
                status: .accepted,
                createdAt: Date()
            )
        ]

        let viewModel = makeViewModel(
            mode: .social,
            connectionRepository: connections
        )

        await viewModel.load()

        #expect(viewModel.relationship == .matched)
        if case .loaded = viewModel.state {
            // ok
        } else {
            Issue.record("Expected loaded profile state")
        }
    }

    @Test func socialConnectSendsRequest() async {
        let connections = MockConnectionRepository()
        let viewModel = makeViewModel(
            mode: .social,
            connectionRepository: connections
        )

        await viewModel.load()
        await viewModel.connect()

        #expect(connections.sendConnectCallCount == 1)
        #expect(connections.lastSendConnectUserId == "peer-1")
        #expect(viewModel.relationship == .pending)
    }

    private func makeViewModel(
        mode: PeerProfileMode,
        connectionRepository: MockConnectionRepository = MockConnectionRepository(),
        userRepository: MockUserRepository = MockUserRepository(),
        communityRepository: MockCommunityRepository = MockCommunityRepository()
    ) -> PeerProfileViewModel {
        PeerProfileViewModel(
            userId: "peer-1",
            mode: mode,
            userRepository: userRepository,
            connectionRepository: connectionRepository,
            communityRepository: communityRepository
        )
    }
}
