import Combine
import Foundation

/// How the shared peer profile sheet behaves.
enum PeerProfileMode: Equatable, Sendable {
    /// Liked You — Like accepts, Skip declines the incoming request.
    case likedYou(requestId: String)
    /// Chats / Communities / Matches — Connect / Pending / Remove.
    case social
}

/// UI relationship for social mode (maps from `ConnectionStatus`).
enum PeerRelationship: Equatable, Sendable {
    /// No doc, or declined — Connect is available.
    case none
    /// Outgoing or incoming pending request.
    case pending
    /// Accepted match — show Remove, never Connect.
    case matched
}

/// Loads another user's public profile and owns mode-specific actions.
/// Does **not** open chat. Owner Profile is separate (`ProfileView`).
@MainActor
final class PeerProfileViewModel: ObservableObject {
    @Published private(set) var state: ViewState<User> = .idle
    @Published private(set) var communities: [Community] = []
    @Published private(set) var relationship: PeerRelationship = .none
    @Published private(set) var isActing = false
    @Published private(set) var actionErrorMessage: String?
    /// Set after a successful like/skip so the sheet can dismiss.
    @Published private(set) var didCompleteAction = false

    let userId: String
    let mode: PeerProfileMode

    private let userRepository: UserRepository
    private let connectionRepository: ConnectionRepository
    private let communityRepository: CommunityRepository

    /// How many community chips to show before “+N”.
    static let visibleCommunityLimit = 3

    init(
        userId: String,
        mode: PeerProfileMode = .social,
        userRepository: UserRepository,
        connectionRepository: ConnectionRepository,
        communityRepository: CommunityRepository
    ) {
        self.userId = userId
        self.mode = mode
        self.userRepository = userRepository
        self.connectionRepository = connectionRepository
        self.communityRepository = communityRepository
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

    func load() async {
        state = .loading
        actionErrorMessage = nil
        didCompleteAction = false

        do {
            let user = try await userRepository.fetchProfile(userId: userId)

            var nextRelationship: PeerRelationship = .none
            if mode == .social {
                // Must succeed — never guess `.none` on failure (would show a false Connect CTA).
                let request = try await connectionRepository.fetchConnection(with: userId)
                nextRelationship = Self.relationship(from: request)
            }

            guard !Task.isCancelled else { return }

            state = .loaded(user)
            relationship = nextRelationship

            // Soft-fail communities so a membership glitch still shows the profile.
            do {
                communities = try await communityRepository.fetchCommunities(forUserId: userId)
            } catch {
                communities = []
            }
        } catch {
            guard !Task.isCancelled else { return }
            state = .error(error.localizedDescription)
        }
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
