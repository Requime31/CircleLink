import Foundation
import Testing
@testable import CircleLink

@MainActor
struct OutgoingLikesDataTests {
    @Test func repositoryRequiresCurrentUserBeforeQueryingFirestore() async {
        let repository = FirestoreConnectionRepository(currentUserID: { nil })

        do {
            _ = try await repository.fetchOutgoingPendingRequests()
            Issue.record("Expected notAuthenticated")
        } catch let error as FirestoreConnectionError {
            if case .notAuthenticated = error {
                // Expected.
            } else {
                Issue.record("Expected notAuthenticated, got \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func mockContractReturnsOnlyPendingNewestFirst() async throws {
        let repository = MockConnectionRepository()
        let old = request(id: "old", peerID: "peer-1", status: .pending, seconds: 1)
        let accepted = request(id: "accepted", peerID: "peer-2", status: .accepted, seconds: 3)
        let newest = request(id: "new", peerID: "peer-3", status: .pending, seconds: 4)
        repository.outgoingPending = [old, accepted, newest]

        let result = try await repository.fetchOutgoingPendingRequests()

        #expect(result.map(\.id) == ["new", "old"])
        #expect(result.allSatisfy { $0.status == .pending })
    }

    @Test func viewModelFiltersBlockedDeactivatedMissingAndWrongDirection() async {
        let connection = MockConnectionRepository()
        connection.outgoingPending = [
            request(id: "good", peerID: "good", seconds: 5),
            request(id: "blocked", peerID: "blocked", seconds: 4),
            request(id: "inactive", peerID: "inactive", seconds: 3),
            request(id: "missing", peerID: "missing", seconds: 2),
            ConnectionRequest(
                id: "incoming", fromUserId: "other", toUserId: "user-1",
                communityId: nil, status: .pending, createdAt: Date(timeIntervalSince1970: 1)
            )
        ]
        let moderation = MockModerationRepository()
        moderation.blockedUserIds = ["blocked"]
        let users = MockUserRepository()
        users.profiles = [
            "user-1": MockAuthRepository.sampleUser,
            "good": User(id: "good", displayName: "Good"),
            "blocked": User(id: "blocked", displayName: "Blocked"),
            "inactive": User(id: "inactive", displayName: "Private", accountState: .deactivated)
        ]
        let viewModel = makeViewModel(
            connection: connection,
            moderation: moderation,
            users: users
        )

        await viewModel.load()

        #expect(outgoingItems(viewModel).map(\.peer.id) == ["good"])
    }

    @Test func viewModelDeduplicatesPeerAndKeepsNewestRequest() async {
        let connection = MockConnectionRepository()
        connection.outgoingPending = [
            request(id: "older", peerID: "peer-1", seconds: 1),
            request(id: "newer", peerID: "peer-1", seconds: 2)
        ]
        let viewModel = makeViewModel(connection: connection)

        await viewModel.loadOutgoingPending()

        #expect(outgoingItems(viewModel).map(\.request.id) == ["newer"])
    }

    @Test func outgoingStateSupportsEmptyAndError() async {
        let connection = MockConnectionRepository()
        let viewModel = makeViewModel(connection: connection)
        await viewModel.loadOutgoingPending()
        #expect(viewModel.outgoingPendingState == .empty)

        connection.outgoingPendingError = NSError(
            domain: "test", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Offline"]
        )
        await viewModel.loadOutgoingPending()
        #expect(viewModel.outgoingPendingState == .error("Offline"))
    }

    @Test func cancellingOutgoingLikeWithdrawsRequestAndRemovesRow() async {
        let connection = MockConnectionRepository()
        connection.outgoingPending = [request(id: "request-1", peerID: "peer-1")]
        let viewModel = makeViewModel(connection: connection)
        await viewModel.loadOutgoingPending()

        await viewModel.cancelOutgoingLike(requestId: "request-1")

        #expect(connection.cancelOutgoingCallCount == 1)
        #expect(connection.lastCancelledOutgoingRequestId == "request-1")
        #expect(viewModel.outgoingPendingState == .empty)
    }

    @Test func failedOutgoingCancellationKeepsRowAndShowsError() async {
        let connection = MockConnectionRepository()
        connection.outgoingPending = [request(id: "request-1", peerID: "peer-1")]
        let viewModel = makeViewModel(connection: connection)
        await viewModel.loadOutgoingPending()
        connection.respondError = NSError(
            domain: "test", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Unable to undo like"]
        )

        await viewModel.cancelOutgoingLike(requestId: "request-1")

        #expect(outgoingItems(viewModel).map(\.request.id) == ["request-1"])
        #expect(viewModel.actionErrorMessage == "Unable to undo like")
    }

    @Test func resetIgnoresStaleOutgoingLoad() async {
        let connection = MockConnectionRepository()
        connection.outgoingPending = [request(id: "late", peerID: "peer-1")]
        connection.shouldSuspendOutgoingPending = true
        let viewModel = makeViewModel(connection: connection)

        let task = Task { await viewModel.loadOutgoingPending() }
        for _ in 0..<100 where !connection.hasPendingOutgoingPendingFetch { await Task.yield() }
        viewModel.resetForm()
        connection.resumeOutgoingPendingFetch()
        await task.value

        #expect(viewModel.outgoingPendingState == .idle)
    }

    @Test func sessionChangeIgnoresStaleOutgoingLoad() async {
        let connection = MockConnectionRepository()
        connection.outgoingPending = [request(id: "late", peerID: "peer-1")]
        connection.shouldSuspendOutgoingPending = true
        let auth = MockAuthRepository(currentUser: MockAuthRepository.sampleUser)
        let viewModel = makeViewModel(connection: connection, auth: auth)

        let task = Task { await viewModel.loadOutgoingPending() }
        for _ in 0..<100 where !connection.hasPendingOutgoingPendingFetch { await Task.yield() }
        auth.currentUser = User(id: "new-session", displayName: "New")
        connection.resumeOutgoingPendingFetch()
        await task.value

        #expect(viewModel.outgoingPendingState == .loading)
    }

    private func makeViewModel(
        connection: MockConnectionRepository = MockConnectionRepository(),
        moderation: MockModerationRepository = MockModerationRepository(),
        users: MockUserRepository = MockUserRepository(),
        auth: MockAuthRepository = MockAuthRepository(currentUser: MockAuthRepository.sampleUser)
    ) -> ConnectViewModel {
        ConnectViewModel(
            connectionRepository: connection,
            chatRepository: MockChatRepository(),
            communityRepository: MockCommunityRepository(),
            userRepository: users,
            authRepository: auth,
            moderationRepository: moderation,
            onOpenChat: { _, _ in }
        )
    }

    private func request(
        id: String,
        peerID: String,
        status: ConnectionStatus = .pending,
        seconds: TimeInterval = 1
    ) -> ConnectionRequest {
        ConnectionRequest(
            id: id,
            fromUserId: "user-1",
            toUserId: peerID,
            communityId: nil,
            status: status,
            createdAt: Date(timeIntervalSince1970: seconds)
        )
    }

    private func outgoingItems(_ viewModel: ConnectViewModel) -> [OutgoingConnectRequestItem] {
        guard case let .loaded(items) = viewModel.outgoingPendingState else { return [] }
        return items
    }
}
