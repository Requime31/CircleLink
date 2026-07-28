import Combine
import Foundation

@MainActor
final class CommunitiesViewModel: ObservableObject {
    @Published private(set) var state: ViewState<[Community]> = .idle
    @Published private(set) var isCreating = false
    @Published private(set) var createErrorMessage: String?
    @Published var searchQuery = ""
    /// `nil` means All categories.
    @Published var selectedInterestTag: String?

    private let communityRepository: CommunityRepository
    private var refreshTask: Task<Void, Never>?

    init(communityRepository: CommunityRepository) {
        self.communityRepository = communityRepository
    }

    /// Unique interest tags from the loaded list, sorted A→Z.
    var availableInterestTags: [String] {
        guard case let .loaded(communities) = state else { return [] }
        return Array(
            Set(
                communities
                    .map(\.interestTag)
                    .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            )
        )
        .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    /// Client-side filter over the full loaded list.
    var filteredCommunities: [Community] {
        guard case let .loaded(communities) = state else { return [] }
        return Self.filter(
            communities,
            searchQuery: searchQuery,
            selectedInterestTag: selectedInterestTag
        )
    }

    /// Cancels any in-flight refresh, then reloads with a spinner.
    func loadCommunities() async {
        refreshTask?.cancel()
        let task = Task<Void, Never> { [weak self] in
            await self?.refreshCommunities(showLoading: true)
        }
        refreshTask = task
        await task.value
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
            // Drop a selected tag that no longer exists after refresh.
            if let selectedInterestTag,
               !communities.contains(where: { $0.interestTag == selectedInterestTag }) {
                self.selectedInterestTag = nil
            }
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

    func clearFilters() {
        searchQuery = ""
        selectedInterestTag = nil
    }

    func resetForm() {
        refreshTask?.cancel()
        refreshTask = nil
        state = .idle
        isCreating = false
        createErrorMessage = nil
        clearFilters()
    }

    /// Pure filter helper — easy to reason about and test later.
    static func filter(
        _ communities: [Community],
        searchQuery: String,
        selectedInterestTag: String?
    ) -> [Community] {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        return communities.filter { community in
            if let selectedInterestTag, community.interestTag != selectedInterestTag {
                return false
            }
            guard !trimmed.isEmpty else { return true }
            return community.name.localizedCaseInsensitiveContains(trimmed)
                || community.description.localizedCaseInsensitiveContains(trimmed)
                || community.interestTag.localizedCaseInsensitiveContains(trimmed)
        }
    }
}
