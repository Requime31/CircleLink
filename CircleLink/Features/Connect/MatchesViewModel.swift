import Combine
import Foundation

/// Matches screen: accepted connections + open direct chat.
@MainActor
final class MatchesViewModel: ObservableObject {
    @Published private(set) var matchedState: ViewState<[MatchedConnectionItem]> = .idle
    @Published private(set) var actionErrorMessage: String?
    @Published private(set) var openingChatPeerId: String?

    private let connectionRepository: ConnectionRepository
    private let chatRepository: ChatRepository
    private let userRepository: UserRepository
    private let authRepository: AuthRepository
    private let blockFilter: ConnectBlockFilter
    private let onOpenChat: (String) -> Void

    private var loadTask: Task<Void, Never>?
    private var loadGeneration = 0
    /// Only `resetForm()` bumps this — distinguishes sign-out from a normal reload.
    private var sessionGeneration = 0

    var matchedCount: Int {
        guard case let .loaded(items) = matchedState else { return 0 }
        return items.count
    }

    init(
        connectionRepository: ConnectionRepository,
        chatRepository: ChatRepository,
        userRepository: UserRepository,
        authRepository: AuthRepository,
        blockFilter: ConnectBlockFilter,
        onOpenChat: @escaping (String) -> Void
    ) {
        self.connectionRepository = connectionRepository
        self.chatRepository = chatRepository
        self.userRepository = userRepository
        self.authRepository = authRepository
        self.blockFilter = blockFilter
        self.onOpenChat = onOpenChat
    }

    func load() async {
        loadGeneration += 1
        let generation = loadGeneration
        loadTask?.cancel()

        matchedState = .loading

        let task = Task { @MainActor in
            do {
                let requests = try await self.connectionRepository.fetchMatchedConnections()
                let currentUserId = self.authRepository.currentUser?.id
                let unresolved: [(request: ConnectionRequest, peerId: String)] = requests.compactMap { request in
                    let peerId = request.fromUserId == currentUserId ? request.toUserId : request.fromUserId
                    guard !self.blockFilter.contains(peerId) else { return nil }
                    return (request, peerId)
                }

                guard !Task.isCancelled, generation == self.loadGeneration else { return }

                guard !unresolved.isEmpty else {
                    self.matchedState = .empty
                    return
                }

                // Missing profiles are omitted by fetchProfiles — same skip behavior as before.
                let profiles = try await self.userRepository.fetchProfiles(userIds: unresolved.map(\.peerId))
                guard !Task.isCancelled, generation == self.loadGeneration else { return }

                let items = unresolved.compactMap { pair -> MatchedConnectionItem? in
                    guard let peer = profiles[pair.peerId] else { return nil }
                    return MatchedConnectionItem(request: pair.request, peer: peer)
                }

                self.matchedState = items.isEmpty ? .empty : .loaded(items)
            } catch {
                guard !Task.isCancelled, generation == self.loadGeneration else { return }
                self.matchedState = .error(error.localizedDescription)
            }
        }
        loadTask = task
        await task.value
    }

    func openChat(with peerId: String) async {
        let session = sessionGeneration
        openingChatPeerId = peerId
        actionErrorMessage = nil

        do {
            let chatId = try await chatRepository.createDirectChat(with: peerId)
            guard session == sessionGeneration else { return }
            onOpenChat(chatId)
        } catch {
            guard session == sessionGeneration else { return }
            actionErrorMessage = error.localizedDescription
        }

        guard session == sessionGeneration else { return }
        openingChatPeerId = nil
    }

    func removeLocally(userId: String) {
        if case let .loaded(matched) = matchedState {
            let filtered = matched.filter { $0.peer.id != userId }
            matchedState = filtered.isEmpty ? .empty : .loaded(filtered)
        }
    }

    func resetForm() {
        loadTask?.cancel()
        loadTask = nil
        loadGeneration += 1
        sessionGeneration += 1
        matchedState = .idle
        actionErrorMessage = nil
        openingChatPeerId = nil
    }
}
