import Combine
import Foundation

/// Thin Connect-tab shell: owns the three screen VMs + shared block filter.
/// Coordinator / MainTabView keep one object; screen logic lives in the child VMs.
@MainActor
final class ConnectTabModel: ObservableObject {
    let discovery: ConnectDiscoveryViewModel
    let inbox: ConnectionInboxViewModel
    let matches: MatchesViewModel

    @Published private(set) var actionErrorMessage: String?
    @Published private(set) var moderationMessage: String?
    @Published private(set) var moderatingUserId: String?
    @Published private(set) var blockedUsersErrorMessage: String?

    private let moderationRepository: ModerationRepository
    private let blockFilter: ConnectBlockFilter
    private var cancellables = Set<AnyCancellable>()
    /// Invalidates in-flight `load()` / moderation after sign-out `resetForm()`.
    private var sessionGeneration = 0
    private var loadTask: Task<Void, Never>?
    private var peerSheetRefreshTask: Task<Void, Never>?

    var incomingCount: Int { inbox.incomingCount }
    var matchedCount: Int { matches.matchedCount }
    var selectedCommunityId: String? { discovery.selectedCommunityId }

    init(
        connectionRepository: ConnectionRepository,
        chatRepository: ChatRepository,
        communityRepository: CommunityRepository,
        userRepository: UserRepository,
        authRepository: AuthRepository,
        moderationRepository: ModerationRepository,
        onOpenChat: @escaping (String) -> Void
    ) {
        let blockFilter = ConnectBlockFilter(moderationRepository: moderationRepository)
        self.blockFilter = blockFilter
        self.moderationRepository = moderationRepository

        self.discovery = ConnectDiscoveryViewModel(
            connectionRepository: connectionRepository,
            communityRepository: communityRepository,
            blockFilter: blockFilter
        )
        self.inbox = ConnectionInboxViewModel(
            connectionRepository: connectionRepository,
            userRepository: userRepository,
            blockFilter: blockFilter
        )
        self.matches = MatchesViewModel(
            connectionRepository: connectionRepository,
            chatRepository: chatRepository,
            userRepository: userRepository,
            authRepository: authRepository,
            blockFilter: blockFilter,
            onOpenChat: onOpenChat
        )

        // Badge counts / child @Published updates must refresh ConnectView toolbar.
        discovery.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        inbox.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        matches.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        inbox.onAcceptSucceeded = { [weak self] in
            guard let self else { return }
            await self.matches.load()
            await self.discovery.reloadCandidatesIfNeeded()
        }
    }

    func load() async {
        loadTask?.cancel()
        let generation = sessionGeneration

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.performLoad(generation: generation)
        }
        loadTask = task
        await task.value
    }

    func refreshAfterPeerSheet() async {
        peerSheetRefreshTask?.cancel()
        let generation = sessionGeneration

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.inbox.load()
            guard !Task.isCancelled, generation == self.sessionGeneration else { return }
            await self.matches.load()
            guard !Task.isCancelled, generation == self.sessionGeneration else { return }
            await self.discovery.reloadCandidatesIfNeeded()
        }
        peerSheetRefreshTask = task
        await task.value
    }

    func report(
        userId: String,
        reason: ReportReason,
        communityId: String? = nil
    ) async {
        guard moderatingUserId == nil else { return }
        let generation = sessionGeneration
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
            guard generation == sessionGeneration else { return }
            moderationMessage = "Thanks — we’ll review this report."
        } catch {
            guard generation == sessionGeneration else { return }
            actionErrorMessage = error.localizedDescription
        }

        guard generation == sessionGeneration else { return }
        moderatingUserId = nil
    }

    func block(userId: String) async {
        guard moderatingUserId == nil else { return }
        let generation = sessionGeneration
        moderatingUserId = userId
        actionErrorMessage = nil
        moderationMessage = nil

        do {
            try await moderationRepository.blockUser(userId)
            guard generation == sessionGeneration else { return }
            blockFilter.insert(userId)
            discovery.removeLocally(userId: userId)
            inbox.removeLocally(userId: userId)
            matches.removeLocally(userId: userId)
            moderationMessage = "User blocked. They won’t appear in Connect."
        } catch {
            guard generation == sessionGeneration else { return }
            actionErrorMessage = error.localizedDescription
        }

        guard generation == sessionGeneration else { return }
        moderatingUserId = nil
    }

    func clearModerationFeedback() {
        moderationMessage = nil
    }

    func resetForm() {
        loadTask?.cancel()
        loadTask = nil
        peerSheetRefreshTask?.cancel()
        peerSheetRefreshTask = nil
        sessionGeneration += 1
        discovery.resetForm()
        inbox.resetForm()
        matches.resetForm()
        // Re-wire accept callback after inbox.resetForm clears it.
        inbox.onAcceptSucceeded = { [weak self] in
            guard let self else { return }
            await self.matches.load()
            await self.discovery.reloadCandidatesIfNeeded()
        }
        blockFilter.reset()
        actionErrorMessage = nil
        moderationMessage = nil
        moderatingUserId = nil
        blockedUsersErrorMessage = nil
    }

    // MARK: - Private

    private func performLoad(generation: Int) async {
        let blockedUsersErrorMessage = await blockFilter.refresh()
        guard !Task.isCancelled, generation == sessionGeneration else { return }
        self.blockedUsersErrorMessage = blockedUsersErrorMessage

        async let discoveryLoad: Void = discovery.load()
        async let inboxLoad: Void = inbox.load()
        async let matchesLoad: Void = matches.load()
        _ = await (discoveryLoad, inboxLoad, matchesLoad)
    }
}
