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

/// Display model for a pending request sent by the current user.
struct OutgoingConnectRequestItem: Identifiable, Equatable, Sendable {
    let request: ConnectionRequest
    let peer: User

    var id: String { request.id }
}

@MainActor
final class ConnectViewModel: ObservableObject {
    @Published private(set) var candidatesState: ViewState<[User]> = .idle
    @Published private(set) var incomingState: ViewState<[ConnectRequestItem]> = .idle
    @Published private(set) var matchedState: ViewState<[MatchedConnectionItem]> = .idle
    @Published private(set) var outgoingPendingState: ViewState<[OutgoingConnectRequestItem]> = .idle

    @Published private(set) var actionErrorMessage: String?
    @Published private(set) var moderationMessage: String?
    @Published private(set) var respondingRequestId: String?
    @Published private(set) var openingChatPeerId: String?
    @Published private(set) var moderatingUserId: String?
    @Published private(set) var blockErrorMessage: String?
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
    private let onOpenChat: (String, String) -> Void

    private var blockedUserIds = Set<String>()
    private var candidatesLoadGeneration = 0
    private var topCommunitiesLoadGeneration = 0
    private var incomingLoadGeneration = 0
    private var matchedLoadGeneration = 0
    private var outgoingPendingLoadGeneration = 0
    private var blockedLoadGeneration = 0
    private var interestsLoadGeneration = 0
    private var sessionGeneration = 0
    private var profileObservationTask: Task<Void, Never>?
    private var myInterests: [String] = []
    /// Avoid empty→loaded flicker when switching cards.
    private var communitiesByUserId: [String: [Community]] = [:]

    /// Ranked candidates minus people Pass'd / Say Hi'd this session.
    var deckCandidates: [User] {
        guard case let .loaded(candidates) = candidatesState else { return [] }
        return candidates.filter { !passedCandidateIds.contains($0.id) }
    }

    var topCandidate: User? { deckCandidates.first }
    var nextCandidate: User? { deckCandidates.dropFirst().first }
    var followingCandidate: User? { deckCandidates.dropFirst(2).first }

    var canUndoPass: Bool { !passUndoStack.isEmpty }

    var incomingCount: Int {
        guard case let .loaded(items) = incomingState else { return 0 }
        return items.count
    }

    var matchedCount: Int {
        guard case let .loaded(items) = matchedState else { return 0 }
        return items.count
    }

    var outgoingPendingCount: Int {
        guard case let .loaded(items) = outgoingPendingState else { return 0 }
        return items.count
    }

    func sharedInterests(with peer: User) -> [String] {
        let mine = Set(myInterests.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
        return peer.interests.filter {
            mine.contains($0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
        }
    }

    init(
        connectionRepository: ConnectionRepository,
        chatRepository: ChatRepository,
        communityRepository: CommunityRepository,
        userRepository: UserRepository,
        authRepository: AuthRepository,
        moderationRepository: ModerationRepository,
        onOpenChat: @escaping (String, String) -> Void
    ) {
        self.connectionRepository = connectionRepository
        self.chatRepository = chatRepository
        self.communityRepository = communityRepository
        self.userRepository = userRepository
        self.authRepository = authRepository
        self.moderationRepository = moderationRepository
        self.onOpenChat = onOpenChat
    }

    deinit {
        profileObservationTask?.cancel()
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
        await loadOutgoingPending(showLoading: !hasOutgoingPendingContent)
        guard generation == sessionGeneration, !Task.isCancelled else { return }
        await loadCandidates(showLoading: !hasCandidatesContent)
        restartProfileObservation()
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
        await loadOutgoingPending(showLoading: false)
        guard generation == sessionGeneration, !Task.isCancelled else { return }
        await loadCandidates(showLoading: false)
        restartProfileObservation()
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

    private var hasOutgoingPendingContent: Bool {
        if case .loaded = outgoingPendingState { return true }
        if case .empty = outgoingPendingState { return true }
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
    @discardableResult
    func sayHi(to userId: String) -> Bool {
        guard prepareSayHi(userId: userId) else { return false }
        let generation = sessionGeneration
        Task { await completeSayHi(userId: userId, generation: generation) }
        return true
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
            await loadOutgoingPending(showLoading: false)
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

    /// Screen-scoped refresh: retain existing rows while checking for status changes.
    func refreshOutgoingPending() async {
        await loadOutgoingPending(showLoading: !hasOutgoingPendingContent)
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

    @discardableResult
    func block(userId: String) async -> Bool {
        guard moderatingUserId == nil else { return false }
        let generation = sessionGeneration
        moderatingUserId = userId
        defer {
            if generation == sessionGeneration {
                moderatingUserId = nil
            }
        }
        actionErrorMessage = nil
        blockErrorMessage = nil
        moderationMessage = nil

        do {
            try await moderationRepository.blockUser(userId)
            guard generation == sessionGeneration, !Task.isCancelled else { return false }
            blockedUserIds.insert(userId)
            removeLocally(userId: userId)
            moderationMessage = "User blocked. They won’t appear in Connect."
            Task { await refreshQuietly() }
            return true
        } catch {
            guard generation == sessionGeneration, !Task.isCancelled else { return false }
            blockErrorMessage = error.localizedDescription
            return false
        }
    }

    func prepareBlockConfirmation() {
        blockErrorMessage = nil
    }

    /// Used by successful blocks initiated from peer profile or direct chat.
    func handlePeerBlocked(userId: String) {
        guard !userId.isEmpty else { return }
        blockedUserIds.insert(userId)
        removeLocally(userId: userId)
        Task { await refreshQuietly() }
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

    func cancelOutgoingLike(requestId: String) async {
        guard respondingRequestId == nil else { return }
        let generation = sessionGeneration
        respondingRequestId = requestId
        defer {
            if generation == sessionGeneration { respondingRequestId = nil }
        }
        actionErrorMessage = nil

        do {
            try await connectionRepository.cancelOutgoingRequest(requestId: requestId)
            guard generation == sessionGeneration, !Task.isCancelled else { return }
            if case let .loaded(items) = outgoingPendingState {
                let remaining = items.filter { $0.request.id != requestId }
                outgoingPendingState = remaining.isEmpty ? .empty : .loaded(remaining)
            }
            await loadCandidates(showLoading: false)
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
            let title = matchedPeerTitle(peerId: peerId)
            onOpenChat(chatId, title)
        } catch {
            guard generation == sessionGeneration, !Task.isCancelled else { return }
            actionErrorMessage = error.localizedDescription
        }
    }

    private func matchedPeerTitle(peerId: String) -> String {
        guard case let .loaded(items) = matchedState,
              let peer = items.first(where: { $0.peer.id == peerId })?.peer else {
            return "Chat"
        }
        let name = peer.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Chat" : name
    }

    func resetForm() {
        profileObservationTask?.cancel()
        profileObservationTask = nil
        candidatesState = .idle
        incomingState = .idle
        matchedState = .idle
        outgoingPendingState = .idle
        actionErrorMessage = nil
        moderationMessage = nil
        respondingRequestId = nil
        openingChatPeerId = nil
        moderatingUserId = nil
        blockErrorMessage = nil
        isSendingConnect = false
        blockedUserIds = []
        myInterests = []
        topCandidateCommunities = []
        communitiesByUserId = [:]
        candidatesLoadGeneration += 1
        topCommunitiesLoadGeneration += 1
        incomingLoadGeneration += 1
        matchedLoadGeneration += 1
        outgoingPendingLoadGeneration += 1
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

    private var observedProfileIDs: Set<String> {
        var ids = Set<String>()
        if case let .loaded(candidates) = candidatesState {
            ids.formUnion(candidates.map(\.id))
        }
        if case let .loaded(items) = incomingState {
            ids.formUnion(items.map(\.peer.id))
        }
        if case let .loaded(items) = matchedState {
            ids.formUnion(items.map(\.peer.id))
        }
        if case let .loaded(items) = outgoingPendingState {
            ids.formUnion(items.map(\.peer.id))
        }
        return ids
    }

    private func restartProfileObservation() {
        profileObservationTask?.cancel()
        profileObservationTask = nil
        let ids = observedProfileIDs
        guard !ids.isEmpty else { return }
        let expectedSession = sessionGeneration

        profileObservationTask = Task { [weak self, userRepository] in
            do {
                for try await user in userRepository.observeProfiles(userIds: ids) {
                    guard let self,
                          !Task.isCancelled,
                          self.sessionGeneration == expectedSession else { return }
                    self.applyObservedProfile(user)
                }
            } catch is CancellationError {
                // Expected when the visible set or signed-in session changes.
            } catch {
                // One-shot loads remain the fallback if the live listener fails.
            }
        }
    }

    private func applyObservedProfile(_ user: User) {
        guard user.isSociallyAvailable, !blockedUserIds.contains(user.id) else {
            removeLocally(userId: user.id)
            return
        }

        if case let .loaded(candidates) = candidatesState,
           let index = candidates.firstIndex(where: { $0.id == user.id }) {
            var updated = candidates
            updated[index] = user
            candidatesState = .loaded(updated)
        }
        if case let .loaded(items) = incomingState,
           let index = items.firstIndex(where: { $0.peer.id == user.id }) {
            var updated = items
            updated[index] = ConnectRequestItem(request: updated[index].request, peer: user)
            incomingState = .loaded(updated)
        }
        if case let .loaded(items) = matchedState,
           let index = items.firstIndex(where: { $0.peer.id == user.id }) {
            var updated = items
            updated[index] = MatchedConnectionItem(request: updated[index].request, peer: user)
            matchedState = .loaded(updated)
        }
        if case let .loaded(items) = outgoingPendingState,
           let index = items.firstIndex(where: { $0.peer.id == user.id }) {
            var updated = items
            updated[index] = OutgoingConnectRequestItem(request: updated[index].request, peer: user)
            outgoingPendingState = .loaded(updated)
        }
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
        if case let .loaded(outgoing) = outgoingPendingState {
            let filtered = outgoing.filter { $0.peer.id != userId }
            outgoingPendingState = filtered.isEmpty ? .empty : .loaded(filtered)
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
                .filter { $0.isSociallyAvailable && !blockedUserIds.contains($0.id) }
            let ranked = ConnectCandidateRanker.ranked(raw, matching: myInterests)
            guard generation == candidatesLoadGeneration, !Task.isCancelled else { return }

            // Keep session Pass ids across refreshes. A transient repository result
            // may omit a peer and include them again later; pruning here would put
            // an already-swiped card back into the deck.
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
                    if peer.isSociallyAvailable {
                        items.append(MatchedConnectionItem(request: request, peer: peer))
                    }
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

    func loadOutgoingPending(showLoading: Bool = true) async {
        outgoingPendingLoadGeneration += 1
        let generation = outgoingPendingLoadGeneration
        let session = sessionGeneration
        if showLoading { outgoingPendingState = .loading }

        guard let currentUserId = authRepository.currentUser?.id else {
            guard generation == outgoingPendingLoadGeneration else { return }
            outgoingPendingState = .error(FirestoreConnectionError.notAuthenticated.localizedDescription)
            return
        }

        do {
            let requests = try await connectionRepository.fetchOutgoingPendingRequests()
            guard generation == outgoingPendingLoadGeneration,
                  session == sessionGeneration,
                  authRepository.currentUser?.id == currentUserId,
                  !Task.isCancelled else { return }

            var seenPeers = Set<String>()
            var items: [OutgoingConnectRequestItem] = []
            let ordered = requests
                .filter { $0.fromUserId == currentUserId && $0.status == .pending }
                .sorted {
                    if $0.createdAt != $1.createdAt { return $0.createdAt > $1.createdAt }
                    return $0.id < $1.id
                }

            for request in ordered {
                let peerId = request.toUserId
                guard !peerId.isEmpty,
                      !blockedUserIds.contains(peerId),
                      seenPeers.insert(peerId).inserted else { continue }
                do {
                    let peer = try await userRepository.fetchProfile(userId: peerId)
                    guard generation == outgoingPendingLoadGeneration,
                          session == sessionGeneration,
                          authRepository.currentUser?.id == currentUserId,
                          !Task.isCancelled else { return }
                    if peer.isSociallyAvailable {
                        items.append(OutgoingConnectRequestItem(request: request, peer: peer))
                    }
                } catch {
                    guard generation == outgoingPendingLoadGeneration,
                          session == sessionGeneration,
                          !Task.isCancelled else { return }
                    continue
                }
            }

            guard generation == outgoingPendingLoadGeneration,
                  session == sessionGeneration,
                  !Task.isCancelled else { return }
            outgoingPendingState = items.isEmpty ? .empty : .loaded(items)
        } catch {
            guard generation == outgoingPendingLoadGeneration,
                  session == sessionGeneration,
                  !Task.isCancelled else { return }
            if showLoading || !hasOutgoingPendingContent {
                outgoingPendingState = .error(error.localizedDescription)
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
                if peer.isSociallyAvailable {
                    items.append(ConnectRequestItem(request: request, peer: peer))
                }
            } catch {
                // Skip broken peer profiles so one missing user doesn't fail Liked You.
                continue
            }
        }

        return items
    }
}
