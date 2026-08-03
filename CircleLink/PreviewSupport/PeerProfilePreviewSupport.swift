#if DEBUG
import SwiftUI

enum PeerProfilePreviewData {
    static let sampleUser = User(
        id: "peer-1",
        displayName: "Alex Rivera",
        avatarURL: nil,
        avatarBase64: nil,
        interests: ["Music", "Travel", "Photography"],
        ageConfirmedAt: Date()
    )

    static func viewModel(
        relationship: PeerRelationship,
        communityId: String? = "community-1"
    ) -> PeerProfileViewModel {
        let users = PreviewPeerUserRepository(user: sampleUser)
        let connections = StubConnectionRepository()

        switch relationship {
        case .none:
            connections.connection = nil
        case .pending:
            connections.connection = ConnectionRequest(
                id: "a_b",
                fromUserId: "me",
                toUserId: sampleUser.id,
                communityId: "community-1",
                status: .pending,
                createdAt: Date()
            )
        case .matched:
            connections.connection = ConnectionRequest(
                id: "a_b",
                fromUserId: "me",
                toUserId: sampleUser.id,
                communityId: "community-1",
                status: .accepted,
                createdAt: Date()
            )
        }

        return PeerProfileViewModel(
            userId: sampleUser.id,
            communityId: communityId,
            userRepository: users,
            connectionRepository: connections
        )
    }
}

private final class PreviewPeerUserRepository: UserRepository, @unchecked Sendable {
    private let user: User

    init(user: User) {
        self.user = user
    }

    func fetchProfile(userId: String) async throws -> User { user }

    func fetchProfiles(userIds: [String]) async throws -> [String: User] {
        userIds.contains(user.id) ? [user.id: user] : [:]
    }

    func updateProfile(_ user: User) async throws {}
    func confirmAge() async throws {}
    func updateFCMToken(_ token: String) async throws {}
    func clearFCMToken() async throws {}
}

#Preview("Connect available") {
    PeerProfileSheet(viewModel: PeerProfilePreviewData.viewModel(relationship: .none))
}

#Preview("Request sent") {
    PeerProfileSheet(viewModel: PeerProfilePreviewData.viewModel(relationship: .pending))
}

#Preview("Matched / Remove") {
    PeerProfileSheet(viewModel: PeerProfilePreviewData.viewModel(relationship: .matched))
}

#Preview("No community context") {
    PeerProfileSheet(
        viewModel: PeerProfilePreviewData.viewModel(
            relationship: .none,
            communityId: nil
        )
    )
}
#endif
