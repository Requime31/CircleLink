import Combine
import Foundation

/// How the shared peer profile sheet behaves.
enum PeerProfileMode: Equatable, Sendable {
    /// Liked You — Like accepts, Skip declines the incoming request.
    case likedYou(requestId: String)
    /// Chats / Communities / Matches — Connect / Pending / Message.
    case social
    /// Informational profile reached from an outgoing pending request.
    case readOnly
}

/// UI relationship for social mode (maps from `ConnectionStatus`).
enum PeerRelationship: Equatable, Sendable {
    /// No doc, or declined — Connect is available.
    case none
    /// Outgoing or incoming pending request.
    case pending
    /// Accepted match — show Message, never Connect.
    case matched
}

/// Loads another user's public profile and owns mode-specific actions.
/// Opens chat only after an explicit matched-profile action. Owner Profile is separate (`ProfileView`).
@MainActor
final class PeerProfileViewModel: ObservableObject {
    @Published private(set) var state: ViewState<User> = .idle
    @Published private(set) var communities: [Community] = []
    @Published private(set) var posts: [ProfilePost] = []
    @Published private(set) var relationship: PeerRelationship = .none
    @Published private(set) var isActing = false
    @Published private(set) var isOpeningChat = false
    @Published private(set) var actionErrorMessage: String?
    /// Set after a successful like/skip so the sheet can dismiss.
    @Published private(set) var didCompleteAction = false
    @Published private(set) var isBlocking = false
    @Published private(set) var blockErrorMessage: String?
    @Published private(set) var didBlock = false

    let userId: String
    let mode: PeerProfileMode

    private let userRepository: UserRepository
    private let connectionRepository: ConnectionRepository
    private let communityRepository: CommunityRepository
    private let profilePostRepository: ProfilePostRepository
    private let chatRepository: ChatRepository
    private let moderationRepository: ModerationRepository
    private let onBlocked: (String) -> Void
    private var generation = 0
    private var profileObservationTask: Task<Void, Never>?

    /// How many community chips to show before “+N”.
    static let visibleCommunityLimit = 3

    init(
        userId: String,
        mode: PeerProfileMode = .social,
        userRepository: UserRepository,
        connectionRepository: ConnectionRepository,
        communityRepository: CommunityRepository,
        profilePostRepository: ProfilePostRepository,
        chatRepository: ChatRepository,
        moderationRepository: ModerationRepository,
        onBlocked: @escaping (String) -> Void = { _ in }
    ) {
        self.userId = userId
        self.mode = mode
        self.userRepository = userRepository
        self.connectionRepository = connectionRepository
        self.communityRepository = communityRepository
        self.profilePostRepository = profilePostRepository
        self.chatRepository = chatRepository
        self.moderationRepository = moderationRepository
        self.onBlocked = onBlocked
    }

    deinit {
        profileObservationTask?.cancel()
    }

    var visibleCommunities: [Community] {
        Array(communities.prefix(Self.visibleCommunityLimit))
    }

    var overflowCommunityCount: Int {
        max(0, communities.count - Self.visibleCommunityLimit)
    }

    var canConnect: Bool {
        mode == .social && relationship == .none
    }

    var peerDisplayName: String {
        if case let .loaded(user) = state { return user.displayName }
        return "this user"
    }

    func load() async {
        generation += 1
        let currentGeneration = generation
        state = .loading
        actionErrorMessage = nil
        didCompleteAction = false

        do {
            let user = try await userRepository.fetchProfile(userId: userId)
            guard user.isSociallyAvailable else {
                state = .error("This profile is no longer available.")
                return
            }

            var nextRelationship: PeerRelationship = .none
            if mode == .social {
                // Must succeed — never guess `.none` on failure (would show a false Connect CTA).
                let request = try await connectionRepository.fetchConnection(with: userId)
                nextRelationship = Self.relationship(from: request)
            }

            guard currentGeneration == generation, !Task.isCancelled else { return }

            state = .loaded(user)
            relationship = nextRelationship
            startProfileObservation(expectedGeneration: currentGeneration)

            // Secondary public content soft-fails so one unavailable collection
            // never prevents the core profile from being viewed.
            async let loadedCommunities = try? communityRepository.fetchCommunities(forUserId: userId)
            async let loadedPosts = try? profilePostRepository.fetchPosts(
                userId: userId,
                limit: 30,
                before: nil
            )
            let (nextCommunities, nextPosts) = await (loadedCommunities, loadedPosts)
            guard currentGeneration == generation, !Task.isCancelled else { return }
            communities = nextCommunities ?? []
            posts = nextPosts ?? []
        } catch {
            guard currentGeneration == generation, !Task.isCancelled else { return }
            state = .error(error.localizedDescription)
        }
    }

    private func startProfileObservation(expectedGeneration: Int) {
        profileObservationTask?.cancel()
        profileObservationTask = Task { [weak self, userRepository, userId] in
            do {
                for try await user in userRepository.observeProfiles(userIds: [userId]) {
                    guard let self,
                          !Task.isCancelled,
                          self.generation == expectedGeneration else { return }
                    self.state = user.isSociallyAvailable
                        ? .loaded(user)
                        : .error("This profile is no longer available.")
                }
            } catch is CancellationError {
                // Expected when the sheet closes or starts a new load.
            } catch {
                // Keep the last successfully loaded profile as a fallback.
            }
        }
    }

    @discardableResult
    func block() async -> Bool {
        guard !isBlocking else { return false }
        let currentGeneration = generation
        isBlocking = true
        blockErrorMessage = nil
        defer {
            if currentGeneration == generation { isBlocking = false }
        }

        do {
            try await moderationRepository.blockUser(userId)
            guard currentGeneration == generation, !Task.isCancelled else { return false }
            didBlock = true
            onBlocked(userId)
            return true
        } catch {
            guard currentGeneration == generation, !Task.isCancelled else { return false }
            blockErrorMessage = error.localizedDescription
            return false
        }
    }

    func prepareBlockConfirmation() {
        blockErrorMessage = nil
    }

    // MARK: - Social actions

    func connect() async {
        guard mode == .social, relationship == .none, !isActing else { return }

        isActing = true
        actionErrorMessage = nil
        defer { isActing = false }

        do {
            try await connectionRepository.sendConnect(to: userId)
            relationship = .pending
        } catch {
            if !Task.isCancelled {
                actionErrorMessage = error.localizedDescription
            }
        }
    }

    /// Unmatch only — does not delete chat history.
    func removeConnection() async {
        guard mode == .social, relationship == .matched, !isActing else { return }

        isActing = true
        actionErrorMessage = nil
        defer { isActing = false }

        do {
            try await connectionRepository.removeConnection(with: userId)
            relationship = .none
        } catch {
            if !Task.isCancelled {
                actionErrorMessage = error.localizedDescription
            }
        }
    }

    func openChat() async -> (chatId: String, title: String)? {
        guard mode == .social, relationship == .matched, !isOpeningChat else { return nil }
        isOpeningChat = true
        actionErrorMessage = nil
        defer { isOpeningChat = false }

        do {
            let chatId = try await chatRepository.createDirectChat(with: userId)
            let title = state.loadedValue?.displayName ?? "Chat"
            return (chatId, title)
        } catch {
            if !Task.isCancelled { actionErrorMessage = error.localizedDescription }
            return nil
        }
    }

    // MARK: - Liked You actions

    /// Accept the incoming request.
    func like() async {
        guard case let .likedYou(requestId) = mode, !isActing else { return }

        isActing = true
        actionErrorMessage = nil
        defer { isActing = false }

        do {
            try await connectionRepository.respond(to: requestId, accept: true)
            didCompleteAction = true
        } catch {
            if !Task.isCancelled {
                actionErrorMessage = error.localizedDescription
            }
        }
    }

    /// Decline the incoming request.
    func skip() async {
        guard case let .likedYou(requestId) = mode, !isActing else { return }

        isActing = true
        actionErrorMessage = nil
        defer { isActing = false }

        do {
            try await connectionRepository.respond(to: requestId, accept: false)
            didCompleteAction = true
        } catch {
            if !Task.isCancelled {
                actionErrorMessage = error.localizedDescription
            }
        }
    }

    private static func relationship(from request: ConnectionRequest?) -> PeerRelationship {
        guard let request else { return .none }
        switch request.status {
        case .pending:
            return .pending
        case .accepted:
            return .matched
        case .declined:
            return .none
        }
    }
}

private extension ViewState {
    var loadedValue: T? {
        if case let .loaded(value) = self { return value }
        return nil
    }
}
