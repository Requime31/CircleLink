import Combine
import Foundation

/// Liked you screen: incoming Connect requests (accept / decline).
@MainActor
final class ConnectionInboxViewModel: ObservableObject {
    @Published private(set) var incomingState: ViewState<[ConnectRequestItem]> = .idle
    @Published private(set) var actionErrorMessage: String?
    @Published private(set) var respondingRequestId: String?

    private let connectionRepository: ConnectionRepository
    private let userRepository: UserRepository
    private let blockFilter: ConnectBlockFilter

    /// Shell wires this to refresh Matches (+ Discover candidates) after accept.
    var onAcceptSucceeded: (() async -> Void)?

    private var loadTask: Task<Void, Never>?
    private var loadGeneration = 0
    /// Only `resetForm()` bumps this — distinguishes sign-out from a normal reload.
    private var sessionGeneration = 0

    var incomingCount: Int {
        guard case let .loaded(items) = incomingState else { return 0 }
        return items.count
    }

    init(
        connectionRepository: ConnectionRepository,
        userRepository: UserRepository,
        blockFilter: ConnectBlockFilter
    ) {
        self.connectionRepository = connectionRepository
        self.userRepository = userRepository
        self.blockFilter = blockFilter
    }

    func load() async {
        loadGeneration += 1
        let generation = loadGeneration
        loadTask?.cancel()

        incomingState = .loading

        let task = Task { @MainActor in
            do {
                let requests = try await self.connectionRepository.fetchIncomingRequests()
                let items = try await self.resolveRequestItems(requests, peerId: \.fromUserId)
                    .filter { !self.blockFilter.contains($0.peer.id) }
                guard !Task.isCancelled, generation == self.loadGeneration else { return }
                self.incomingState = items.isEmpty ? .empty : .loaded(items)
            } catch {
                guard !Task.isCancelled, generation == self.loadGeneration else { return }
                self.incomingState = .error(error.localizedDescription)
            }
        }
        loadTask = task
        await task.value
    }

    func accept(requestId: String, fromUserId: String) async {
        _ = fromUserId
        let session = sessionGeneration
        respondingRequestId = requestId
        actionErrorMessage = nil

        do {
            try await connectionRepository.respond(to: requestId, accept: true)
        } catch {
            guard session == sessionGeneration else { return }
            actionErrorMessage = error.localizedDescription
            respondingRequestId = nil
            return
        }

        guard session == sessionGeneration else { return }

        // Accept only — user opens chat manually from Matches (no auto-navigation).
        await load()
        guard session == sessionGeneration else { return }
        await onAcceptSucceeded?()

        guard session == sessionGeneration else { return }
        respondingRequestId = nil
    }

    func decline(requestId: String) async {
        let session = sessionGeneration
        respondingRequestId = requestId
        actionErrorMessage = nil

        do {
            try await connectionRepository.respond(to: requestId, accept: false)
            guard session == sessionGeneration else { return }
            await load()
        } catch {
            guard session == sessionGeneration else { return }
            actionErrorMessage = error.localizedDescription
        }

        guard session == sessionGeneration else { return }
        respondingRequestId = nil
    }

    func removeLocally(userId: String) {
        if case let .loaded(incoming) = incomingState {
            let filtered = incoming.filter { $0.peer.id != userId }
            incomingState = filtered.isEmpty ? .empty : .loaded(filtered)
        }
    }

    func resetForm() {
        loadTask?.cancel()
        loadTask = nil
        loadGeneration += 1
        sessionGeneration += 1
        incomingState = .idle
        actionErrorMessage = nil
        respondingRequestId = nil
        onAcceptSucceeded = nil
    }

    // MARK: - Private

    private func resolveRequestItems(
        _ requests: [ConnectionRequest],
        peerId: KeyPath<ConnectionRequest, String>
    ) async throws -> [ConnectRequestItem] {
        guard !requests.isEmpty else { return [] }

        let profiles = try await userRepository.fetchProfiles(
            userIds: requests.map { $0[keyPath: peerId] }
        )

        // Missing docs are omitted (batch contract). Previously a single fetchProfile
        // failure failed the whole incoming section — skipping is safer for lists.
        return requests.compactMap { request in
            let id = request[keyPath: peerId]
            guard let peer = profiles[id] else { return nil }
            return ConnectRequestItem(request: request, peer: peer)
        }
    }
}
