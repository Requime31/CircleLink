import Combine
import Foundation

@MainActor
final class CommunitiesViewModel: ObservableObject {
    private let communityRepository: CommunityRepository

    init(communityRepository: CommunityRepository) {
        self.communityRepository = communityRepository
    }
}
