import Combine
import Foundation

/// Discover screen: community picker + candidate deck (pass / view profile).
@MainActor
final class ConnectDiscoveryViewModel: ObservableObject {
    @Published private(set) var communitiesState: ViewState<[Community]> = .idle
    @Published private(set) var candidatesState: ViewState<[User]> = .idle
    @Published private(set) var selectedCommunityId: String?

    /// Session-only Pass skips — not persisted; cleared on community change / resetForm only.
    @Published private(set) var passedCandidateIds: Set<String> = []

    private let connectionRepository: ConnectionRepository
    private let communityRepository: CommunityRepository
    private let blockFilter: ConnectBlockFilter

    /// Ignores stale candidate responses when the user switches community quickly.
    private var candidatesLoadGeneration = 0
    /// Bumped on reset so in-flight community loads cannot repopulate after sign-out.
    private var sessionGeneration = 0
    private var candidatesLoadTask: Task<Void, Never>?
    private var communitiesLoadTask: Task<Void, Never>?

    /// Ranked candidates minus people Pass'd this session.
    var deckCandidates: [User] {
        guard case let .loaded(candidates) = candidatesState else { return [] }
        return candidates.filter { !passedCandidateIds.contains($0.id) }
    }

    var topCandidate: User? { deckCandidates.first }

    init(
        connectionRepository: ConnectionRepository,
        communityRepository: CommunityRepository,
        blockFilter: ConnectBlockFilter
    ) {
        self.connectionRepository = connectionRepository
        self.communityRepository = communityRepository
        self.blockFilter = blockFilter
    }

    func load() async {
        await loadCommunities()
        if let selectedCommunityId {
            await loadCandidates(communityId: selectedCommunityId)
        }
    }

    func reloadCandidatesIfNeeded() async {
        guard let selectedCommunityId else { return }
        await loadCandidates(communityId: selectedCommunityId)
    }

    /// Local Pass only — does not hide the peer in Firestore.
    func passCandidate(userId: String) {
        guard !userId.isEmpty else { return }
        passedCandidateIds.insert(userId)
    }

    func selectCommunity(_ communityId: String) async {
        selectedCommunityId = communityId
        resetPassedCandidates()
        await loadCandidates(communityId: communityId)
    }

    func removeLocally(userId: String) {
        if case let .loaded(candidates) = candidatesState {
            let filtered = candidates.filter { $0.id != userId }
            candidatesState = filtered.isEmpty ? .empty : .loaded(filtered)
        }
    }

    func resetForm() {
        communitiesLoadTask?.cancel()
        communitiesLoadTask = nil
        candidatesLoadTask?.cancel()
        candidatesLoadTask = nil
        sessionGeneration += 1
        communitiesState = .idle
        candidatesState = .idle
        selectedCommunityId = nil
        candidatesLoadGeneration += 1
        resetPassedCandidates()
    }

    // MARK: - Private

    private func resetPassedCandidates() {
        passedCandidateIds = []
    }

    private func loadCommunities() async {
        communitiesLoadTask?.cancel()
        let generation = sessionGeneration
        communitiesState = .loading

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let communities = try await self.communityRepository.fetchCommunities()
                guard !Task.isCancelled, generation == self.sessionGeneration else { return }
                self.communitiesState = communities.isEmpty ? .empty : .loaded(communities)

                if self.selectedCommunityId == nil, let first = communities.first {
                    self.selectedCommunityId = first.id
                }
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled, generation == self.sessionGeneration else { return }
                self.communitiesState = .error(error.localizedDescription)
            }
        }
        communitiesLoadTask = task
        await task.value
    }

    private func loadCandidates(communityId: String) async {
        candidatesLoadGeneration += 1
        let generation = candidatesLoadGeneration
        candidatesLoadTask?.cancel()

        candidatesState = .loading

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let candidates = try await self.connectionRepository.fetchCandidates(communityId: communityId)
                    .filter { !self.blockFilter.contains($0.id) }
                guard !Task.isCancelled,
                      generation == self.candidatesLoadGeneration,
                      self.selectedCommunityId == communityId
                else { return }

                // Drop session Pass ids that are no longer in the fresh list.
                self.passedCandidateIds = self.passedCandidateIds.intersection(Set(candidates.map(\.id)))
                self.candidatesState = candidates.isEmpty ? .empty : .loaded(candidates)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled,
                      generation == self.candidatesLoadGeneration,
                      self.selectedCommunityId == communityId
                else { return }
                self.candidatesState = .error(error.localizedDescription)
            }
        }
        candidatesLoadTask = task
        await task.value
    }
}
