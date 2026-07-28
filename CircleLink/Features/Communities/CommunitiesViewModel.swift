import Combine
import Foundation

@MainActor
final class CommunitiesViewModel: ObservableObject {
    @Published private(set) var state: ViewState<[Community]> = .idle
    @Published private(set) var isCreating = false
    @Published private(set) var createErrorMessage: String?

    private let communityRepository: CommunityRepository

    init(communityRepository: CommunityRepository) {
        self.communityRepository = communityRepository
    }

    func loadCommunities() async {
        state = .loading

        do {
            let communities = try await communityRepository.fetchCommunities()
            state = communities.isEmpty ? .empty : .loaded(communities)
        } catch {
            state = .error(error.localizedDescription)
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
        state = .idle
        isCreating = false
        createErrorMessage = nil
    }
}
