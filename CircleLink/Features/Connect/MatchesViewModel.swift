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
    private var openChatTask: Task<Void, Never>?

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

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
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
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled, generation == self.loadGeneration else { return }
                self.matchedState = .error(error.localizedDescription)
            }
        }
        loadTask = task
        await task.value
    }

    func openChat(with peerId: String) async {
        // Global guard: open-chat navigates; concurrent creates would double-open.
        guard openingChatPeerId == nil, openChatTask == nil else { return }
        let session = sessionGeneration
        openingChatPeerId = peerId
        actionErrorMessage = nil

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                if self.sessionGeneration == session {
                    self.openingChatPeerId = nil
                }
            }

            do {
                let chatId = try await self.chatRepository.createDirectChat(with: peerId)
                guard !Task.isCancelled, session == self.sessionGeneration else { return }
                self.onOpenChat(chatId)
            } catch is CancellationError {
                return
            } catch {
                guard session == self.sessionGeneration else { return }
                self.actionErrorMessage = error.localizedDescription
            }
        }
        openChatTask = task
        await task.value
        if openChatTask == task {
            openChatTask = nil
        }
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
        openChatTask?.cancel()
        openChatTask = nil
        loadGeneration += 1
        sessionGeneration += 1
        matchedState = .idle
        actionErrorMessage = nil
        openingChatPeerId = nil
    }
}
