import Combine
import Foundation

@MainActor
final class CommunitiesViewModel: ObservableObject {
    @Published private(set) var state: ViewState<[Community]> = .idle
    @Published private(set) var isCreating = false
    @Published private(set) var createErrorMessage: String?

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

    /// Returns `true` when the community was created and the list reloaded.
    @discardableResult
    func createCommunity(
        name: String,
        description: String,
        interestTag: String
    ) async -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            createErrorMessage = "Enter a community name."
            return false
        }

        isCreating = true
        createErrorMessage = nil

        do {
            _ = try await communityRepository.createCommunity(
                name: trimmedName,
                description: description,
                interestTag: interestTag
            )
            await loadCommunities()
            isCreating = false
            return true
        } catch {
            createErrorMessage = error.localizedDescription
            isCreating = false
            return false
        }
    }

    func clearCreateError() {
        createErrorMessage = nil
    }

    func resetForm() {
        refreshTask?.cancel()
        refreshTask = nil
        state = .idle
        isCreating = false
        createErrorMessage = nil
    }
}
