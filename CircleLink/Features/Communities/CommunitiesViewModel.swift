import Combine
import Foundation

@MainActor
final class CommunitiesViewModel: ObservableObject {
    @Published private(set) var state: ViewState<[Community]> = .idle

    private let communityRepository: CommunityRepository
    private var refreshTask: Task<Void, Never>?

    init(communityRepository: CommunityRepository) {
        self.communityRepository = communityRepository
    }

    func loadCommunities() async {
        await refreshCommunities(showLoading: true)
    }

    /// Reloads when the list appears. Quiet if we already have a settled result.
    func refreshOnAppear() {
        let showLoading: Bool
        switch state {
        case .loaded, .empty:
            showLoading = false
        case .idle, .loading, .error:
            showLoading = true
        }
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            await self?.refreshCommunities(showLoading: showLoading)
        }
    }

    /// Reloads list. When already settled, skips the loading spinner (e.g. return from detail).
    func refreshCommunities(showLoading: Bool = true) async {
        if showLoading {
            state = .loading
        }

        do {
            let communities = try await communityRepository.fetchCommunities()
            guard !Task.isCancelled else { return }
            state = communities.isEmpty ? .empty : .loaded(communities)
        } catch {
            guard !Task.isCancelled else { return }
            if showLoading {
                state = .error(error.localizedDescription)
            }
            // Quiet refresh failure: keep existing loaded/empty UI instead of flashing an error.
        }
    }

    func resetForm() {
        refreshTask?.cancel()
        refreshTask = nil
        state = .idle
    }
}
