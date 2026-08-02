import Foundation

/// Leaves a community safely for Firestore rules: drop group-chat access first, then membership.
/// Multi-repo: `ChatRepository` then `CommunityRepository` (order matters).
struct LeaveCommunityUseCase: Sendable {
    private let chatRepository: ChatRepository
    private let communityRepository: CommunityRepository

    init(chatRepository: ChatRepository, communityRepository: CommunityRepository) {
        self.chatRepository = chatRepository
        self.communityRepository = communityRepository
    }

    func execute(communityId: String) async throws {
        // Drop group chat access first — group write rules still require membership.
        try await chatRepository.leaveGroupChat(communityId: communityId)
        try await communityRepository.leave(communityId: communityId)
    }
}
