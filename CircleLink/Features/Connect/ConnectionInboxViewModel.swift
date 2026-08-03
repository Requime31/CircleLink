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
    private var actionTask: Task<Void, Never>?

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

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let requests = try await self.connectionRepository.fetchIncomingRequests()
                let items = try await self.resolveRequestItems(requests, peerId: \.fromUserId)
                    .filter { !self.blockFilter.contains($0.peer.id) }
                guard !Task.isCancelled, generation == self.loadGeneration else { return }
                self.incomingState = items.isEmpty ? .empty : .loaded(items)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled, generation == self.loadGeneration else { return }
                self.incomingState = .error(error.localizedDescription)
            }
        }
        loadTask = task
        await task.value
    }

    func accept(requestId: String, fromUserId: String) async {
        // Global guard: accept/decline refresh the whole inbox; concurrent actions race.
        guard respondingRequestId == nil, actionTask == nil else { return }
        _ = fromUserId
        let session = sessionGeneration
        respondingRequestId = requestId
        actionErrorMessage = nil

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                if self.sessionGeneration == session {
                    self.respondingRequestId = nil
                }
            }

            do {
                try await self.connectionRepository.respond(to: requestId, accept: true)
            } catch is CancellationError {
                return
            } catch {
                guard session == self.sessionGeneration else { return }
                self.actionErrorMessage = error.localizedDescription
                return
            }

            guard !Task.isCancelled, session == self.sessionGeneration else { return }

            // Accept only — user opens chat manually from Matches (no auto-navigation).
            await self.load()
            guard !Task.isCancelled, session == self.sessionGeneration else { return }
            await self.onAcceptSucceeded?()
        }
        actionTask = task
        await task.value
        if actionTask == task {
            actionTask = nil
        }
    }

    func decline(requestId: String) async {
        guard respondingRequestId == nil, actionTask == nil else { return }
        let session = sessionGeneration
        respondingRequestId = requestId
        actionErrorMessage = nil

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                if self.sessionGeneration == session {
                    self.respondingRequestId = nil
                }
            }

            do {
                try await self.connectionRepository.respond(to: requestId, accept: false)
                guard !Task.isCancelled, session == self.sessionGeneration else { return }
                await self.load()
            } catch is CancellationError {
                return
            } catch {
                guard session == self.sessionGeneration else { return }
                self.actionErrorMessage = error.localizedDescription
            }
        }
        actionTask = task
        await task.value
        if actionTask == task {
            actionTask = nil
        }
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
        actionTask?.cancel()
        actionTask = nil
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
