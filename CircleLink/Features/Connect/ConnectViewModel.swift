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
    private var incomingLoadGeneration = 0
    private var matchedLoadGeneration = 0
    private var blockedLoadGeneration = 0
    private var interestsLoadGeneration = 0
    private var sessionGeneration = 0
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
        let generation = sessionGeneration
        await loadBlockedUsers()
        guard generation == sessionGeneration, !Task.isCancelled else { return }
        await loadMyInterests()
        guard generation == sessionGeneration, !Task.isCancelled else { return }
        await loadIncoming(showLoading: !hasIncomingContent)
        guard generation == sessionGeneration, !Task.isCancelled else { return }
        await loadMatched(showLoading: !hasMatchedContent)
        guard generation == sessionGeneration, !Task.isCancelled else { return }
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
        let generation = sessionGeneration
        await loadBlockedUsers()
        guard generation == sessionGeneration, !Task.isCancelled else { return }
        await loadIncoming(showLoading: false)
        guard generation == sessionGeneration, !Task.isCancelled else { return }
        await loadMatched(showLoading: false)
        guard generation == sessionGeneration, !Task.isCancelled else { return }
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
        let generation = sessionGeneration
        Task { await completeSayHi(userId: userId, generation: generation) }
    }

    /// Same as `sayHi`, awaited until the request finishes.
    func sayHiAndWait(to userId: String) async {
        guard prepareSayHi(userId: userId) else { return }
        await completeSayHi(userId: userId, generation: sessionGeneration)
    }

    @discardableResult
    private func prepareSayHi(userId: String) -> Bool {
        guard !userId.isEmpty, !isSendingConnect else { return false }
        isSendingConnect = true
        actionErrorMessage = nil
        passedCandidateIds.insert(userId)
        return true
    }

    private func completeSayHi(userId: String, generation: Int) async {
        defer {
            if generation == sessionGeneration {
                isSendingConnect = false
            }
        }
        await refreshTopCandidateCommunities()
        guard generation == sessionGeneration, !Task.isCancelled else { return }

        do {
            try await connectionRepository.sendConnect(to: userId)
            guard generation == sessionGeneration, !Task.isCancelled else { return }
            await loadIncoming(showLoading: false)
            guard generation == sessionGeneration, !Task.isCancelled else { return }
            await loadMatched(showLoading: false)
            guard generation == sessionGeneration, !Task.isCancelled else { return }
            await loadCandidates(showLoading: false)
            guard generation == sessionGeneration, !Task.isCancelled else { return }
            await refreshTopCandidateCommunities()
        } catch {
            guard generation == sessionGeneration, !Task.isCancelled else { return }
            passedCandidateIds.remove(userId)
            actionErrorMessage = error.localizedDescription
            await refreshTopCandidateCommunities()
        }
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
        let generation = sessionGeneration
        moderatingUserId = userId
        defer {
            if generation == sessionGeneration {
                moderatingUserId = nil
            }
        }
        actionErrorMessage = nil
        moderationMessage = nil

        do {
            try await moderationRepository.reportUser(
                userId: userId,
                reason: reason,
                chatId: nil,
                communityId: communityId
            )
            guard generation == sessionGeneration, !Task.isCancelled else { return }
            moderationMessage = "Thanks — we’ll review this report."
        } catch {
            guard generation == sessionGeneration, !Task.isCancelled else { return }
            actionErrorMessage = error.localizedDescription
        }
    }

    func block(userId: String) async {
        guard moderatingUserId == nil else { return }
        let generation = sessionGeneration
        moderatingUserId = userId
        defer {
            if generation == sessionGeneration {
                moderatingUserId = nil
            }
        }
        actionErrorMessage = nil
        moderationMessage = nil

        do {
            try await moderationRepository.blockUser(userId)
            guard generation == sessionGeneration, !Task.isCancelled else { return }
            blockedUserIds.insert(userId)
            removeLocally(userId: userId)
            moderationMessage = "User blocked. They won’t appear in Connect."
        } catch {
            guard generation == sessionGeneration, !Task.isCancelled else { return }
            actionErrorMessage = error.localizedDescription
        }
    }

    func clearModerationFeedback() {
        moderationMessage = nil
    }

    func accept(requestId: String, fromUserId: String) async {
        guard respondingRequestId == nil else { return }
        let generation = sessionGeneration
        _ = fromUserId
        respondingRequestId = requestId
        defer {
            if generation == sessionGeneration {
                respondingRequestId = nil
            }
        }
        actionErrorMessage = nil

        do {
            try await connectionRepository.respond(to: requestId, accept: true)
            guard generation == sessionGeneration, !Task.isCancelled else { return }
        } catch {
            guard generation == sessionGeneration, !Task.isCancelled else { return }
            actionErrorMessage = error.localizedDescription
            return
        }

        // Accept only — user opens chat manually from Matches (no auto-navigation).
        await loadIncoming(showLoading: false)
        guard generation == sessionGeneration, !Task.isCancelled else { return }
        await loadMatched(showLoading: false)
        guard generation == sessionGeneration, !Task.isCancelled else { return }
        await loadCandidates(showLoading: false)
    }

    func decline(requestId: String) async {
        guard respondingRequestId == nil else { return }
        let generation = sessionGeneration
        respondingRequestId = requestId
        defer {
            if generation == sessionGeneration {
                respondingRequestId = nil
            }
        }
        actionErrorMessage = nil

        do {
            try await connectionRepository.respond(to: requestId, accept: false)
            guard generation == sessionGeneration, !Task.isCancelled else { return }
            await loadIncoming(showLoading: false)
        } catch {
            guard generation == sessionGeneration, !Task.isCancelled else { return }
            actionErrorMessage = error.localizedDescription
        }
    }

    func openChat(with peerId: String) async {
        guard openingChatPeerId == nil else { return }
        let generation = sessionGeneration
        openingChatPeerId = peerId
        defer {
            if generation == sessionGeneration {
                openingChatPeerId = nil
            }
        }
        actionErrorMessage = nil

        do {
            let chatId = try await chatRepository.createDirectChat(with: peerId)
            guard generation == sessionGeneration, !Task.isCancelled else { return }
            onOpenChat(chatId)
        } catch {
            guard generation == sessionGeneration, !Task.isCancelled else { return }
            actionErrorMessage = error.localizedDescription
        }
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
        incomingLoadGeneration += 1
        matchedLoadGeneration += 1
        blockedLoadGeneration += 1
        interestsLoadGeneration += 1
        sessionGeneration += 1
        resetPassedCandidates()
    }

    // MARK: - Private loads

    private func resetPassedCandidates() {
        passedCandidateIds = []
        passUndoStack = []
    }

    private func loadBlockedUsers() async {
        blockedLoadGeneration += 1
        let generation = blockedLoadGeneration
        do {
            let ids = try await moderationRepository.fetchBlockedUserIds()
            guard generation == blockedLoadGeneration, !Task.isCancelled else { return }
            blockedUserIds = ids
        } catch {
            // Fail closed: keep the last known block set so a refresh blip
            // cannot re-surface people the user already blocked.
        }
    }

    private func loadMyInterests() async {
        interestsLoadGeneration += 1
        let generation = interestsLoadGeneration
        guard let userId = authRepository.currentUser?.id else {
            myInterests = []
            return
        }
        do {
            let me = try await userRepository.fetchProfile(userId: userId)
            guard generation == interestsLoadGeneration,
                  authRepository.currentUser?.id == userId,
                  !Task.isCancelled else { return }
            myInterests = me.interests
        } catch {
            guard generation == interestsLoadGeneration, !Task.isCancelled else { return }
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
            guard generation == candidatesLoadGeneration, !Task.isCancelled else { return }

            // Drop session Pass ids that are no longer in the fresh list.
            passedCandidateIds = passedCandidateIds.intersection(Set(ranked.map(\.id)))
            passUndoStack = passUndoStack.filter { passedCandidateIds.contains($0) }
            candidatesState = ranked.isEmpty ? .empty : .loaded(ranked)
            await refreshTopCandidateCommunities()
        } catch {
            guard generation == candidatesLoadGeneration, !Task.isCancelled else { return }
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
                  topCandidate?.id == userId,
                  !Task.isCancelled
            else { return }
            communitiesByUserId[userId] = joined
            topCandidateCommunities = joined
        } catch {
            guard generation == topCommunitiesLoadGeneration,
                  topCandidate?.id == userId,
                  !Task.isCancelled
            else { return }
            if communitiesByUserId[userId] == nil {
                topCandidateCommunities = []
            }
        }
    }

    private func loadIncoming(showLoading: Bool = true) async {
        incomingLoadGeneration += 1
        let generation = incomingLoadGeneration
        if showLoading {
            incomingState = .loading
        }

        do {
            let requests = try await connectionRepository.fetchIncomingRequests()
            let items = try await resolveRequestItems(requests, peerId: \.fromUserId)
                .filter { !blockedUserIds.contains($0.peer.id) }
            guard generation == incomingLoadGeneration, !Task.isCancelled else { return }
            incomingState = items.isEmpty ? .empty : .loaded(items)
        } catch {
            guard generation == incomingLoadGeneration, !Task.isCancelled else { return }
            if showLoading || !hasIncomingContent {
                incomingState = .error(error.localizedDescription)
            }
        }
    }

    private func loadMatched(showLoading: Bool = true) async {
        matchedLoadGeneration += 1
        let generation = matchedLoadGeneration
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

            guard generation == matchedLoadGeneration, !Task.isCancelled else { return }
            matchedState = items.isEmpty ? .empty : .loaded(items)
        } catch {
            guard generation == matchedLoadGeneration, !Task.isCancelled else { return }
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
