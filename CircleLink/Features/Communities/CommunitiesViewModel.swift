import Combine
import Foundation

@MainActor
final class CommunitiesViewModel: ObservableObject {
    @Published private(set) var state: ViewState<[Community]> = .idle

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

    func resetForm() {
        state = .idle
    }
}
