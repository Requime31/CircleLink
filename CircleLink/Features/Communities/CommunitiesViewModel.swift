import Combine
import Foundation

enum CommunitySortOrder: String, CaseIterable, Hashable, Sendable {
    case popular = "Popular"
    case newest = "Newest"
    case alphabetical = "A–Z"
}

@MainActor
final class CommunitiesViewModel: ObservableObject {
    @Published private(set) var state: ViewState<[Community]> = .idle
    @Published private(set) var isCreating = false
    @Published private(set) var createErrorMessage: String?
    @Published private(set) var hasPendingCreatedCommunity = false
    @Published var searchQuery = ""
    /// `nil` means All categories.
    @Published var selectedInterestTag: String?
    @Published var sortOrder: CommunitySortOrder = .popular

    private let communityRepository: CommunityRepository
    private let communityImageStorage: CommunityImageStorage
    private var pendingCreatedCommunity: Community?
    private var refreshTask: Task<Void, Never>?
    private var createGeneration = 0

    init(
        communityRepository: CommunityRepository,
        communityImageStorage: CommunityImageStorage? = nil
    ) {
        self.communityRepository = communityRepository
        self.communityImageStorage = communityImageStorage ?? StubCommunityImageStorage()
    }

    /// Unique interest tags from the loaded list, sorted A→Z.
    var availableInterestTags: [String] {
        return Array(
            Set(
                allCommunities
                    .map(\.interestTag)
                    .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            )
        )
        .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    /// Complete loaded catalog before search, category filtering, or sorting.
    var allCommunities: [Community] {
        guard case let .loaded(communities) = state else { return [] }
        return communities
    }

    /// Client-side filter over the full loaded list.
    var filteredCommunities: [Community] {
        return Self.filter(
            allCommunities,
            searchQuery: searchQuery,
            selectedInterestTag: selectedInterestTag
        )
    }

    /// Filtered catalog in the user-selected presentation order.
    var sortedCommunities: [Community] {
        Self.sort(filteredCommunities, by: sortOrder)
    }

    /// Most active circles first. The list screen caps this visually unless See all is selected.
    var suggestedCommunities: [Community] {
        Self.sort(filteredCommunities, by: .popular)
    }

    /// Newly created circles first. Legacy records without `createdAt` remain visible after dated ones.
    var newCommunities: [Community] {
        Self.sort(filteredCommunities, by: .newest)
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
        interestTag: String,
        coverImage: Data? = nil
    ) async -> Bool {
        guard !isCreating else { return false }
        createGeneration += 1
        let generation = createGeneration
        let content: ValidatedCommunityContent
        do {
            content = try CommunityContentPolicy.validate(name: name, description: description)
        } catch {
            createErrorMessage = error.localizedDescription
            return false
        }

        isCreating = true
        defer {
            if generation == createGeneration {
                isCreating = false
            }
        }
        createErrorMessage = nil

        do {
            let community: Community
            if let pendingCreatedCommunity {
                try await communityRepository.updateCommunityMetadata(
                    communityId: pendingCreatedCommunity.id,
                    name: content.name,
                    description: content.description
                )
                community = pendingCreatedCommunity
            } else {
                community = try await communityRepository.createCommunity(
                    name: content.name,
                    description: content.description,
                    interestTag: interestTag
                )
                pendingCreatedCommunity = community
                hasPendingCreatedCommunity = true
            }

            if let coverImage {
                do {
                    let url = try await communityImageStorage.uploadCover(
                        data: ImageCompressor.compressForChat(coverImage),
                        communityId: community.id
                    )
                    try await communityRepository.updateCoverURL(communityId: community.id, url: url)
                } catch {
                    guard generation == createGeneration, !Task.isCancelled else { return false }
                    await loadCommunities()
                    createErrorMessage = "The community was saved, but its cover wasn’t. Try Save again to retry the cover."
                    return false
                }
            }
            guard generation == createGeneration, !Task.isCancelled else { return false }
            pendingCreatedCommunity = nil
            hasPendingCreatedCommunity = false
            await loadCommunities()
            guard generation == createGeneration, !Task.isCancelled else { return false }
            return true
        } catch {
            guard generation == createGeneration, !Task.isCancelled else { return false }
            createErrorMessage = error.localizedDescription
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
        createGeneration += 1
        state = .idle
        isCreating = false
        createErrorMessage = nil
        pendingCreatedCommunity = nil
        hasPendingCreatedCommunity = false
        clearFilters()
    }

    nonisolated static func sort(
        _ communities: [Community],
        by order: CommunitySortOrder
    ) -> [Community] {
        communities.sorted { lhs, rhs in
            switch order {
            case .popular:
                if lhs.memberCount != rhs.memberCount {
                    return lhs.memberCount > rhs.memberCount
                }
            case .newest:
                switch (lhs.createdAt, rhs.createdAt) {
                case let (lhsDate?, rhsDate?) where lhsDate != rhsDate:
                    return lhsDate > rhsDate
                case (.some, .none):
                    return true
                case (.none, .some):
                    return false
                default:
                    break
                }
            case .alphabetical:
                break
            }

            return isOrderedByName(lhs, before: rhs)
        }
    }

    nonisolated static func filter(
        _ communities: [Community],
        searchQuery: String,
        selectedInterestTag: String?
    ) -> [Community] {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        return communities.filter { community in
            if let selectedInterestTag {
                let normalizedSelection = selectedInterestTag.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                let normalizedCommunityTag = community.interestTag.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                if normalizedCommunityTag.localizedCaseInsensitiveCompare(normalizedSelection)
                    != .orderedSame {
                    return false
                }
            }
            guard !trimmed.isEmpty else { return true }
            return community.name.localizedCaseInsensitiveContains(trimmed)
                || community.description.localizedCaseInsensitiveContains(trimmed)
                || community.interestTag.localizedCaseInsensitiveContains(trimmed)
        }
    }

    private nonisolated static func isOrderedByName(
        _ lhs: Community,
        before rhs: Community
    ) -> Bool {
        let comparison = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
        if comparison != .orderedSame {
            return comparison == .orderedAscending
        }
        return lhs.id < rhs.id
    }
}
