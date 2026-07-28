import Combine
import Foundation

/// UI relationship for a peer (maps from `ConnectionStatus`).
enum PeerRelationship: Equatable, Sendable {
    /// No doc, or declined — Connect is available when `communityId` is known.
    case none
    /// Outgoing or incoming pending request.
    case pending
    /// Accepted match — show Remove, never Connect.
    case matched
}

/// Loads another user's public profile + connection state.
/// Does **not** open chat. Owner Profile is separate (`ProfileView`).
@MainActor
final class PeerProfileViewModel: ObservableObject {
    @Published private(set) var state: ViewState<User> = .idle
    @Published private(set) var relationship: PeerRelationship = .none
    @Published private(set) var isActing = false
    @Published private(set) var actionErrorMessage: String?

    let userId: String
    /// Needed for Connect. When nil, Connect CTA is hidden.
    let communityId: String?

    private let userRepository: UserRepository
    private let connectionRepository: ConnectionRepository

    init(
        userId: String,
        communityId: String? = nil,
        userRepository: UserRepository,
        connectionRepository: ConnectionRepository
    ) {
        self.userId = userId
        self.communityId = communityId
        self.userRepository = userRepository
        self.connectionRepository = connectionRepository
    }

    /// Show Connect when unmatched and community context exists.
    /// Spinner/disabled is handled separately via `isActing`.
    var canConnect: Bool {
        relationship == .none && communityId != nil
    }

    /// Unmatched but no community — show muted hint instead of Connect.
    var showsConnectUnavailableHint: Bool {
        relationship == .none && communityId == nil
    }

    func load() async {
        state = .loading
        actionErrorMessage = nil

        do {
            async let profile = userRepository.fetchProfile(userId: userId)
            async let connection = connectionRepository.fetchConnection(with: userId)
            let (user, request) = try await (profile, connection)

            guard !Task.isCancelled else { return }

            state = .loaded(user)
            relationship = Self.relationship(from: request)
        } catch {
            guard !Task.isCancelled else { return }
            state = .error(error.localizedDescription)
        }
    }

    func connect() async {
        guard relationship == .none, !isActing else { return }
        guard let communityId else {
            actionErrorMessage = "Connect from a community."
            return
        }

        isActing = true
        actionErrorMessage = nil
        defer { isActing = false }

        do {
            try await connectionRepository.sendConnect(to: userId, in: communityId)
            // Server already updated — reflect even if the view task is cancelling.
            relationship = .pending
        } catch {
            if !Task.isCancelled {
                actionErrorMessage = error.localizedDescription
            }
        }
    }

    /// Unmatch only — does not delete chat history.
    func removeConnection() async {
        guard relationship == .matched, !isActing else { return }

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

    static func relationship(from request: ConnectionRequest?) -> PeerRelationship {
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
