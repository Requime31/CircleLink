import SwiftUI

/// Soft sheet wrapper for another user's profile.
///
/// **Public API (Phases 4 / 5 / 7):**
/// ```swift
/// .sheet(item: $presentedPeer) { item in
///     dependencies.makePeerProfileSheet(
///         userId: item.userId,
///         communityId: item.communityId // pass when known
///     )
/// }
/// ```
/// Sheet owns its ViewModel via `@StateObject` (stable across re-renders).
/// Never auto-opens chat.
struct PeerProfileSheet: View {
    @StateObject private var viewModel: PeerProfileViewModel

    init(
        userId: String,
        communityId: String? = nil,
        userRepository: UserRepository,
        connectionRepository: ConnectionRepository
    ) {
        _viewModel = StateObject(
            wrappedValue: PeerProfileViewModel(
                userId: userId,
                communityId: communityId,
                userRepository: userRepository,
                connectionRepository: connectionRepository
            )
        )
    }

    /// Preview / tests — inject a preconfigured ViewModel.
    init(previewViewModel: PeerProfileViewModel) {
        _viewModel = StateObject(wrappedValue: previewViewModel)
    }

    var body: some View {
        NavigationStack {
            PeerProfileView(viewModel: viewModel)
                .navigationTitle("Profile")
                .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .modifier(PeerProfileSheetChrome())
        .task {
            await viewModel.load()
        }
    }
}

/// Soft sheet corners when the OS supports them (iOS 16.4+).
private struct PeerProfileSheetChrome: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.4, *) {
            content.presentationCornerRadius(CLRadius.xl)
        } else {
            content
        }
    }
}

// MARK: - Previews

#if DEBUG
private enum PeerProfilePreviewData {
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
    func updateProfile(_ user: User) async throws {}
    func confirmAge() async throws {}
    func updateFCMToken(_ token: String) async throws {}
    func clearFCMToken() async throws {}
}

#Preview("Connect available") {
    PeerProfileSheet(previewViewModel: PeerProfilePreviewData.viewModel(relationship: .none))
}

#Preview("Request sent") {
    PeerProfileSheet(previewViewModel: PeerProfilePreviewData.viewModel(relationship: .pending))
}

#Preview("Matched / Remove") {
    PeerProfileSheet(previewViewModel: PeerProfilePreviewData.viewModel(relationship: .matched))
}

#Preview("No community context") {
    PeerProfileSheet(
        previewViewModel: PeerProfilePreviewData.viewModel(
            relationship: .none,
            communityId: nil
        )
    )
}
#endif
