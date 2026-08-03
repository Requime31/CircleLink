import Foundation
import Testing
@testable import CircleLink

@MainActor
struct PeerProfileViewModelTests {
    private func makeViewModel(
        userId: String = "peer-1",
        communityId: String? = "community-1",
        user: MockUserRepository = MockUserRepository(),
        connection: MockConnectionRepository = MockConnectionRepository()
    ) -> PeerProfileViewModel {
        PeerProfileViewModel(
            userId: userId,
            communityId: communityId,
            userRepository: user,
            connectionRepository: connection
        )
    }

    @Test func loadSetsProfileAndRelationshipNone() async {
        let viewModel = makeViewModel()

        await viewModel.load()

        if case let .loaded(user) = viewModel.state {
            #expect(user.id == "peer-1")
        } else {
            Issue.record("Expected loaded peer profile")
        }
        #expect(viewModel.relationship == .none)
        #expect(viewModel.canConnect)
    }

    @Test func loadSetsRelationshipPendingAndMatched() async {
        let connection = MockConnectionRepository()
        connection.connectionsByPeerId["peer-1"] = ConnectionRequest(
            id: "req-1",
            fromUserId: "user-1",
            toUserId: "peer-1",
            communityId: "community-1",
            status: .pending,
            createdAt: Date()
        )
        let pendingVM = makeViewModel(connection: connection)
        await pendingVM.load()
        #expect(pendingVM.relationship == .pending)
        #expect(!pendingVM.canConnect)

        connection.connectionsByPeerId["peer-1"]?.status = .accepted
        let matchedVM = makeViewModel(connection: connection)
        await matchedVM.load()
        #expect(matchedVM.relationship == .matched)
        #expect(!matchedVM.canConnect)
    }

    @Test func loadSurfacesRepositoryError() async {
        struct Boom: LocalizedError {
            var errorDescription: String? { "Profile unavailable" }
        }

        let user = MockUserRepository()
        user.fetchProfileError = Boom()
        let viewModel = makeViewModel(user: user)

        await viewModel.load()

        if case let .error(message) = viewModel.state {
            #expect(message == "Profile unavailable")
        } else {
            Issue.record("Expected error state")
        }
    }

    @Test func connectRequiresCommunityId() async {
        let connection = MockConnectionRepository()
        let viewModel = makeViewModel(communityId: nil, connection: connection)
        await viewModel.load()

        await viewModel.connect()

        #expect(connection.sendConnectCallCount == 0)
        #expect(viewModel.actionErrorMessage == "Connect from a community.")
        #expect(viewModel.showsConnectUnavailableHint)
    }

    @Test func connectSetsPendingOnSuccess() async {
        let connection = MockConnectionRepository()
        let viewModel = makeViewModel(connection: connection)
        await viewModel.load()

        await viewModel.connect()

        #expect(connection.sendConnectCallCount == 1)
        #expect(connection.lastSendConnectUserId == "peer-1")
        #expect(connection.lastSendConnectCommunityId == "community-1")
        #expect(viewModel.relationship == .pending)
        #expect(!viewModel.isActing)
    }

    @Test func removeConnectionSetsNoneOnSuccess() async {
        let connection = MockConnectionRepository()
        connection.connectionsByPeerId["peer-1"] = ConnectionRequest(
            id: "req-1",
            fromUserId: "user-1",
            toUserId: "peer-1",
            communityId: "community-1",
            status: .accepted,
            createdAt: Date()
        )
        let viewModel = makeViewModel(connection: connection)
        await viewModel.load()
        #expect(viewModel.relationship == .matched)

        await viewModel.removeConnection()

        #expect(connection.removeConnectionCallCount == 1)
        #expect(viewModel.relationship == .none)
        #expect(!viewModel.isActing)
    }

    @Test func relationshipMapperCoversStatuses() {
        #expect(PeerProfileViewModel.relationship(from: nil) == .none)

        let pending = ConnectionRequest(
            id: "1",
            fromUserId: "a",
            toUserId: "b",
            communityId: "c",
            status: .pending,
            createdAt: Date()
        )
        #expect(PeerProfileViewModel.relationship(from: pending) == .pending)

        var accepted = pending
        accepted.status = .accepted
        #expect(PeerProfileViewModel.relationship(from: accepted) == .matched)

        var declined = pending
        declined.status = .declined
        #expect(PeerProfileViewModel.relationship(from: declined) == .none)
    }
}
