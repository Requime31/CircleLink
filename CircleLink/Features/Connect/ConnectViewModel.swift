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
    @Published private(set) var candidatesState: ViewState<[User]> = .idle
    @Published private(set) var incomingState: ViewState<[ConnectRequestItem]> = .idle
    @Published private(set) var matchedState: ViewState<[MatchedConnectionItem]> = .idle

    @Published private(set) var actionErrorMessage: String?
    @Published private(set) var moderationMessage: String?
    @Published private(set) var respondingRequestId: String?
    @Published private(set) var openingChatPeerId: String?
    @Published private(set) var moderatingUserId: String?
    @Published private(set) var isSendingConnect = false

    /// Session-only Pass skips — not persisted.
    @Published private(set) var passedCandidateIds: Set<String> = []
    /// Undo stack for the Back button (Pass only).
    @Published private(set) var passUndoStack: [String] = []
    /// Communities for the current Discover top card (inline profile).
    @Published private(set) var topCandidateCommunities: [Community] = []

    private let connectionRepository: ConnectionRepository
    private let chatRepository: ChatRepository
    private let communityRepository: CommunityRepository
    private let userRepository: UserRepository
    private let authRepository: AuthRepository
    private let moderationRepository: ModerationRepository
    private let onOpenChat: (String) -> Void

    private var blockedUserIds = Set<String>()
    private var candidatesLoadGeneration = 0
    private var topCommunitiesLoadGeneration = 0
    private var myInterests: [String] = []
    /// Avoid empty→loaded flicker when switching cards.
    private var communitiesByUserId: [String: [Community]] = [:]

    /// Ranked candidates minus people Pass'd / Say Hi'd this session.
    var deckCandidates: [User] {
        guard case let .loaded(candidates) = candidatesState else { return [] }
        return candidates.filter { !passedCandidateIds.contains($0.id) }
    }

    var topCandidate: User? { deckCandidates.first }

    var canUndoPass: Bool { !passUndoStack.isEmpty }

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
        await loadMyInterests()
        await loadIncoming(showLoading: !hasIncomingContent)
        await loadMatched(showLoading: !hasMatchedContent)
        await loadCandidates(showLoading: !hasCandidatesContent)
    }

    /// First open → full load. Returning from Liked You / Matches → quiet refresh (no spinners).
    func loadIfNeeded() async {
        let isFirstLoad = !hasCandidatesContent && !hasIncomingContent && !hasMatchedContent
        if isFirstLoad {
            await load()
        } else {
            await refreshQuietly()
        }
    }

    /// Refresh lists without flipping UI into `.loading`.
    func refreshQuietly() async {
        await loadBlockedUsers()
        await loadIncoming(showLoading: false)
        await loadMatched(showLoading: false)
        await loadCandidates(showLoading: false)
    }

    private var hasIncomingContent: Bool {
        if case .loaded = incomingState { return true }
        if case .empty = incomingState { return true }
        return false
    }

    private var hasMatchedContent: Bool {
        if case .loaded = matchedState { return true }
        if case .empty = matchedState { return true }
        return false
    }

    private var hasCandidatesContent: Bool {
        if case .loaded = candidatesState { return true }
        if case .empty = candidatesState { return true }
        return false
    }

    /// Local Pass only — does not hide the peer in Firestore.
    func passCandidate(userId: String, undoable: Bool = true) {
        guard !userId.isEmpty else { return }
        passedCandidateIds.insert(userId)
        if undoable {
            passUndoStack.append(userId)
        }
        Task { await refreshTopCandidateCommunities() }
    }

    func undoLastPass() {
        guard let userId = passUndoStack.popLast() else { return }
        passedCandidateIds.remove(userId)
        Task { await refreshTopCandidateCommunities() }
    }

    /// Say Hi from Discover — card leaves the deck in this turn, request goes out after.
    /// Rolls back onto the deck if the request fails.
    func sayHi(to userId: String) {
        guard prepareSayHi(userId: userId) else { return }
        Task { await completeSayHi(userId: userId) }
    }

    /// Same as `sayHi`, awaited until the request finishes.
    func sayHiAndWait(to userId: String) async {
        guard prepareSayHi(userId: userId) else { return }
        await completeSayHi(userId: userId)
    }

    @discardableResult
    private func prepareSayHi(userId: String) -> Bool {
        guard !userId.isEmpty, !isSendingConnect else { return false }
        isSendingConnect = true
        actionErrorMessage = nil
        passedCandidateIds.insert(userId)
        return true
    }

    private func completeSayHi(userId: String) async {
        await refreshTopCandidateCommunities()

        do {
            try await connectionRepository.sendConnect(to: userId)
            await loadIncoming(showLoading: false)
            await loadMatched(showLoading: false)
            await loadCandidates(showLoading: false)
            await refreshTopCandidateCommunities()
        } catch {
            passedCandidateIds.remove(userId)
            actionErrorMessage = error.localizedDescription
            await refreshTopCandidateCommunities()
        }

        isSendingConnect = false
    }

    func refreshAfterPeerSheet() async {
        await refreshQuietly()
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
                communityId: communityId
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
        await loadIncoming(showLoading: false)
        await loadMatched(showLoading: false)
        await loadCandidates(showLoading: false)

        respondingRequestId = nil
    }

    func decline(requestId: String) async {
        respondingRequestId = requestId
        actionErrorMessage = nil

        do {
            try await connectionRepository.respond(to: requestId, accept: false)
            await loadIncoming(showLoading: false)
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
        candidatesState = .idle
        incomingState = .idle
        matchedState = .idle
        actionErrorMessage = nil
        moderationMessage = nil
        respondingRequestId = nil
        openingChatPeerId = nil
        moderatingUserId = nil
        isSendingConnect = false
        blockedUserIds = []
        myInterests = []
        topCandidateCommunities = []
        communitiesByUserId = [:]
        candidatesLoadGeneration += 1
        topCommunitiesLoadGeneration += 1
        resetPassedCandidates()
    }

    // MARK: - Private loads

    private func resetPassedCandidates() {
        passedCandidateIds = []
        passUndoStack = []
    }

    private func loadBlockedUsers() async {
        do {
            blockedUserIds = try await moderationRepository.fetchBlockedUserIds()
        } catch {
            // Fail closed: keep the last known block set so a refresh blip
            // cannot re-surface people the user already blocked.
        }
    }

    private func loadMyInterests() async {
        guard let userId = authRepository.currentUser?.id else {
            myInterests = []
            return
        }
        do {
            let me = try await userRepository.fetchProfile(userId: userId)
            myInterests = me.interests
        } catch {
            myInterests = authRepository.currentUser?.interests ?? []
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

    private func loadCandidates(showLoading: Bool = true) async {
        candidatesLoadGeneration += 1
        let generation = candidatesLoadGeneration
        if showLoading {
            candidatesState = .loading
        }

        do {
            let raw = try await connectionRepository.fetchCandidates()
                .filter { !blockedUserIds.contains($0.id) }
            let ranked = ConnectCandidateRanker.ranked(raw, matching: myInterests)
            guard generation == candidatesLoadGeneration else { return }

            // Drop session Pass ids that are no longer in the fresh list.
            passedCandidateIds = passedCandidateIds.intersection(Set(ranked.map(\.id)))
            passUndoStack = passUndoStack.filter { passedCandidateIds.contains($0) }
            candidatesState = ranked.isEmpty ? .empty : .loaded(ranked)
            await refreshTopCandidateCommunities()
        } catch {
            guard generation == candidatesLoadGeneration else { return }
            candidatesState = .error(error.localizedDescription)
            topCandidateCommunities = []
        }
    }

    private func refreshTopCandidateCommunities() async {
        topCommunitiesLoadGeneration += 1
        let generation = topCommunitiesLoadGeneration
        guard let userId = topCandidate?.id else {
            topCandidateCommunities = []
            return
        }

        if let cached = communitiesByUserId[userId] {
            topCandidateCommunities = cached
        }

        do {
            let joined = try await communityRepository.fetchCommunities(forUserId: userId)
            guard generation == topCommunitiesLoadGeneration,
                  topCandidate?.id == userId
            else { return }
            communitiesByUserId[userId] = joined
            topCandidateCommunities = joined
        } catch {
            guard generation == topCommunitiesLoadGeneration,
                  topCandidate?.id == userId
            else { return }
            if communitiesByUserId[userId] == nil {
                topCandidateCommunities = []
            }
        }
    }

    private func loadIncoming(showLoading: Bool = true) async {
        if showLoading {
            incomingState = .loading
        }

        do {
            let requests = try await connectionRepository.fetchIncomingRequests()
            let items = try await resolveRequestItems(requests, peerId: \.fromUserId)
                .filter { !blockedUserIds.contains($0.peer.id) }
            incomingState = items.isEmpty ? .empty : .loaded(items)
        } catch {
            if showLoading || !hasIncomingContent {
                incomingState = .error(error.localizedDescription)
            }
        }
    }

    private func loadMatched(showLoading: Bool = true) async {
        if showLoading {
            matchedState = .loading
        }

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
            if showLoading || !hasMatchedContent {
                matchedState = .error(error.localizedDescription)
            }
        }
    }

    private func resolveRequestItems(
        _ requests: [ConnectionRequest],
        peerId: KeyPath<ConnectionRequest, String>
    ) async throws -> [ConnectRequestItem] {
        var items: [ConnectRequestItem] = []
        items.reserveCapacity(requests.count)

        for request in requests {
            do {
                let peer = try await userRepository.fetchProfile(userId: request[keyPath: peerId])
                items.append(ConnectRequestItem(request: request, peer: peer))
            } catch {
                // Skip broken peer profiles so one missing user doesn't fail Liked You.
                continue
            }
        }

        return items
    }
}
