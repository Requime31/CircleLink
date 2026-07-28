import Combine
import Foundation

/// Display model for an incoming Connect request with resolved peer profile.
struct ConnectRequestItem: Identifiable, Equatable, Sendable {
    let request: ConnectionRequest
    let peer: User

    var id: String { request.id }
}

/// Display model for an accepted match with resolved peer profile.
struct MatchedConnectionItem: Identifiable, Equatable, Sendable {
    let request: ConnectionRequest
    let peer: User

    var id: String { request.id }
}

@MainActor
final class ConnectViewModel: ObservableObject {
    @Published private(set) var communitiesState: ViewState<[Community]> = .idle
    @Published private(set) var candidatesState: ViewState<[User]> = .idle
    @Published private(set) var incomingState: ViewState<[ConnectRequestItem]> = .idle
    @Published private(set) var matchedState: ViewState<[MatchedConnectionItem]> = .idle

    @Published private(set) var selectedCommunityId: String?
    @Published private(set) var actionErrorMessage: String?
    @Published private(set) var moderationMessage: String?
    @Published private(set) var respondingRequestId: String?
    @Published private(set) var openingChatPeerId: String?
    @Published private(set) var moderatingUserId: String?

    /// Session-only Pass skips — not persisted; cleared on community change / resetForm only.
    @Published private(set) var passedCandidateIds: Set<String> = []

    private let connectionRepository: ConnectionRepository
    private let chatRepository: ChatRepository
    private let communityRepository: CommunityRepository
    private let userRepository: UserRepository
    private let authRepository: AuthRepository
    private let moderationRepository: ModerationRepository
    private let onOpenChat: (String) -> Void

    private var blockedUserIds = Set<String>()
    /// Ignores stale candidate responses when the user switches community quickly.
    private var candidatesLoadGeneration = 0

    /// Ranked candidates minus people Pass'd this session.
    var deckCandidates: [User] {
        guard case let .loaded(candidates) = candidatesState else { return [] }
        return candidates.filter { !passedCandidateIds.contains($0.id) }
    }

    var topCandidate: User? { deckCandidates.first }

    var incomingCount: Int {
        guard case let .loaded(items) = incomingState else { return 0 }
        return items.count
    }

    var matchedCount: Int {
        guard case let .loaded(items) = matchedState else { return 0 }
        return items.count
    }

    init(
        connectionRepository: ConnectionRepository,
        chatRepository: ChatRepository,
        communityRepository: CommunityRepository,
        userRepository: UserRepository,
        authRepository: AuthRepository,
        moderationRepository: ModerationRepository,
        onOpenChat: @escaping (String) -> Void
    ) {
        self.connectionRepository = connectionRepository
        self.chatRepository = chatRepository
        self.communityRepository = communityRepository
        self.userRepository = userRepository
        self.authRepository = authRepository
        self.moderationRepository = moderationRepository
        self.onOpenChat = onOpenChat
    }

    func load() async {
        await loadBlockedUsers()
        await loadCommunities()
        await loadIncoming()
        await loadMatched()

        if let selectedCommunityId {
            await loadCandidates(communityId: selectedCommunityId)
        }
    }

    /// Local Pass only — does not hide the peer in Firestore.
    func passCandidate(userId: String) {
        guard !userId.isEmpty else { return }
        passedCandidateIds.insert(userId)
    }

    func refreshAfterPeerSheet() async {
        await loadIncoming()
        await loadMatched()
        if let selectedCommunityId {
            await loadCandidates(communityId: selectedCommunityId)
        }
    }

    func report(
        userId: String,
        reason: ReportReason,
        communityId: String? = nil
    ) async {
        guard moderatingUserId == nil else { return }
        moderatingUserId = userId
        actionErrorMessage = nil
        moderationMessage = nil

        do {
            try await moderationRepository.reportUser(
                userId: userId,
                reason: reason,
                chatId: nil,
                communityId: communityId ?? selectedCommunityId
            )
            moderationMessage = "Thanks — we’ll review this report."
        } catch {
            actionErrorMessage = error.localizedDescription
        }

        moderatingUserId = nil
    }

    func block(userId: String) async {
        guard moderatingUserId == nil else { return }
        moderatingUserId = userId
        actionErrorMessage = nil
        moderationMessage = nil

        do {
            try await moderationRepository.blockUser(userId)
            blockedUserIds.insert(userId)
            removeLocally(userId: userId)
            moderationMessage = "User blocked. They won’t appear in Connect."
        } catch {
            actionErrorMessage = error.localizedDescription
        }

        moderatingUserId = nil
    }

    func clearModerationFeedback() {
        moderationMessage = nil
    }

    func selectCommunity(_ communityId: String) async {
        selectedCommunityId = communityId
        resetPassedCandidates()
        await loadCandidates(communityId: communityId)
    }

    func accept(requestId: String, fromUserId: String) async {
        _ = fromUserId
        respondingRequestId = requestId
        actionErrorMessage = nil

        do {
            try await connectionRepository.respond(to: requestId, accept: true)
        } catch {
            actionErrorMessage = error.localizedDescription
            respondingRequestId = nil
            return
        }

        // Accept only — user opens chat manually from Matches (no auto-navigation).
        await loadIncoming()
        await loadMatched()
        if let communityId = selectedCommunityId {
            await loadCandidates(communityId: communityId)
        }

        respondingRequestId = nil
    }

    func decline(requestId: String) async {
        respondingRequestId = requestId
        actionErrorMessage = nil

        do {
            try await connectionRepository.respond(to: requestId, accept: false)
            await loadIncoming()
        } catch {
            actionErrorMessage = error.localizedDescription
        }

        respondingRequestId = nil
    }

    func openChat(with peerId: String) async {
        openingChatPeerId = peerId
        actionErrorMessage = nil

        do {
            let chatId = try await chatRepository.createDirectChat(with: peerId)
            onOpenChat(chatId)
        } catch {
            actionErrorMessage = error.localizedDescription
        }

        openingChatPeerId = nil
    }

    func resetForm() {
        communitiesState = .idle
        candidatesState = .idle
        incomingState = .idle
        matchedState = .idle
        selectedCommunityId = nil
        actionErrorMessage = nil
        moderationMessage = nil
        respondingRequestId = nil
        openingChatPeerId = nil
        moderatingUserId = nil
        blockedUserIds = []
        candidatesLoadGeneration += 1
        resetPassedCandidates()
    }

    // MARK: - Private loads

    private func resetPassedCandidates() {
        passedCandidateIds = []
    }

    private func loadBlockedUsers() async {
        do {
            blockedUserIds = try await moderationRepository.fetchBlockedUserIds()
        } catch {
            // Fail closed: keep the last known block set so a refresh blip
            // cannot re-surface people the user already blocked.
        }
    }

    private func removeLocally(userId: String) {
        if case let .loaded(candidates) = candidatesState {
            let filtered = candidates.filter { $0.id != userId }
            candidatesState = filtered.isEmpty ? .empty : .loaded(filtered)
        }
        if case let .loaded(incoming) = incomingState {
            let filtered = incoming.filter { $0.peer.id != userId }
            incomingState = filtered.isEmpty ? .empty : .loaded(filtered)
        }
        if case let .loaded(matched) = matchedState {
            let filtered = matched.filter { $0.peer.id != userId }
            matchedState = filtered.isEmpty ? .empty : .loaded(filtered)
        }
    }

    private func loadCommunities() async {
        communitiesState = .loading

        do {
            let communities = try await communityRepository.fetchCommunities()
            communitiesState = communities.isEmpty ? .empty : .loaded(communities)

            if selectedCommunityId == nil, let first = communities.first {
                selectedCommunityId = first.id
            }
        } catch {
            communitiesState = .error(error.localizedDescription)
        }
    }

    private func loadCandidates(communityId: String) async {
        candidatesLoadGeneration += 1
        let generation = candidatesLoadGeneration
        candidatesState = .loading

        do {
            let candidates = try await connectionRepository.fetchCandidates(communityId: communityId)
                .filter { !blockedUserIds.contains($0.id) }
            guard generation == candidatesLoadGeneration,
                  selectedCommunityId == communityId
            else { return }

            // Drop session Pass ids that are no longer in the fresh list.
            passedCandidateIds = passedCandidateIds.intersection(Set(candidates.map(\.id)))
            candidatesState = candidates.isEmpty ? .empty : .loaded(candidates)
        } catch {
            guard generation == candidatesLoadGeneration,
                  selectedCommunityId == communityId
            else { return }
            candidatesState = .error(error.localizedDescription)
        }
    }

    private func loadIncoming() async {
        incomingState = .loading

        do {
            let requests = try await connectionRepository.fetchIncomingRequests()
            let items = try await resolveRequestItems(requests, peerId: \.fromUserId)
                .filter { !blockedUserIds.contains($0.peer.id) }
            incomingState = items.isEmpty ? .empty : .loaded(items)
        } catch {
            incomingState = .error(error.localizedDescription)
        }
    }

    private func loadMatched() async {
        matchedState = .loading

        do {
            let requests = try await connectionRepository.fetchMatchedConnections()
            let currentUserId = authRepository.currentUser?.id
            var items: [MatchedConnectionItem] = []
            items.reserveCapacity(requests.count)

            for request in requests {
                let peerId = request.fromUserId == currentUserId ? request.toUserId : request.fromUserId
                guard !blockedUserIds.contains(peerId) else { continue }
                do {
                    let peer = try await userRepository.fetchProfile(userId: peerId)
                    items.append(MatchedConnectionItem(request: request, peer: peer))
                } catch {
                    // Skip broken peer profiles so one missing user doesn't fail the section.
                    continue
                }
            }

            matchedState = items.isEmpty ? .empty : .loaded(items)
        } catch {
            matchedState = .error(error.localizedDescription)
        }
    }

    private func resolveRequestItems(
        _ requests: [ConnectionRequest],
        peerId: KeyPath<ConnectionRequest, String>
    ) async throws -> [ConnectRequestItem] {
        var items: [ConnectRequestItem] = []
        items.reserveCapacity(requests.count)

        for request in requests {
            let peer = try await userRepository.fetchProfile(userId: request[keyPath: peerId])
            items.append(ConnectRequestItem(request: request, peer: peer))
        }

        return items
    }
}
