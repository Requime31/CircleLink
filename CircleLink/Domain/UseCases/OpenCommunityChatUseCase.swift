import Foundation

nonisolated enum OpenCommunityChatUseCaseError: LocalizedError, Equatable {
    case notSignedIn
    /// Refreshed member list is included so the UI can update before showing the error.
    case notAMember(members: [User])

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "You must be signed in to open group chat."
        case .notAMember:
            return "Only community members can open this group chat."
        }
    }
}

/// Refreshes members, verifies membership, and creates/opens the community group chat.
/// Multi-repo: `CommunityRepository` + `ChatRepository` (+ session from `AuthRepository`).
struct OpenCommunityChatUseCase: Sendable {
    nonisolated struct Output: Sendable, Equatable {
        let chatId: String
        let members: [User]
    }

    private let communityRepository: CommunityRepository
    private let chatRepository: ChatRepository
    private let authRepository: AuthRepository

    init(
        communityRepository: CommunityRepository,
        chatRepository: ChatRepository,
        authRepository: AuthRepository
    ) {
        self.communityRepository = communityRepository
        self.chatRepository = chatRepository
        self.authRepository = authRepository
    }

    func execute(communityId: String) async throws -> Output {
        guard let currentUserId = authRepository.currentUser?.id else {
            throw OpenCommunityChatUseCaseError.notSignedIn
        }

        // Always refresh members so new joiners get chatRefs on open.
        let members = try await communityRepository.fetchMembers(communityId: communityId)

        guard members.contains(where: { $0.id == currentUserId }) else {
            throw OpenCommunityChatUseCaseError.notAMember(members: members)
        }

        let chatId = try await chatRepository.createGroupChat(
            communityId: communityId,
            participantIds: members.map(\.id)
        )

        return Output(chatId: chatId, members: members)
    }
}
