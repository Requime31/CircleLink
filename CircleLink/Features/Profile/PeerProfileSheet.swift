import SwiftUI

/// Soft sheet wrapper for another user's profile (all modes).
///
/// **Public API:**
/// ```swift
/// .sheet(item: $presentedPeer) { item in
///     dependencies.makePeerProfileSheet(
///         userId: item.userId,
///         mode: .social // or .likedYou(requestId:)
///     )
/// }
/// ```
/// Sheet owns its ViewModel via `@StateObject` (stable across re-renders).
/// Chat opens only after an explicit Message tap on a matched profile.
struct PeerProfileSheet: View {
    @StateObject private var viewModel: PeerProfileViewModel
    let onFinished: () -> Void
    let onOpenChat: (String, String) -> Void
    @Environment(\.dismiss) private var dismiss

    init(
        userId: String,
        mode: PeerProfileMode = .social,
        userRepository: UserRepository,
        connectionRepository: ConnectionRepository,
        communityRepository: CommunityRepository,
        profilePostRepository: ProfilePostRepository,
        chatRepository: ChatRepository,
        onOpenChat: @escaping (String, String) -> Void = { _, _ in },
        onFinished: @escaping () -> Void = {}
    ) {
        _viewModel = StateObject(
            wrappedValue: PeerProfileViewModel(
                userId: userId,
                mode: mode,
                userRepository: userRepository,
                connectionRepository: connectionRepository,
                communityRepository: communityRepository,
                profilePostRepository: profilePostRepository,
                chatRepository: chatRepository
            )
        )
        self.onFinished = onFinished
        self.onOpenChat = onOpenChat
    }

    /// Preview / tests — inject a preconfigured ViewModel.
    init(
        previewViewModel: PeerProfileViewModel,
        onFinished: @escaping () -> Void = {}
    ) {
        _viewModel = StateObject(wrappedValue: previewViewModel)
        self.onFinished = onFinished
        self.onOpenChat = { _, _ in }
    }

    var body: some View {
        PeerProfileView(
            viewModel: viewModel,
            onClose: handleClose,
            onOpenChat: handleOpenChat
        )
        .modifier(PeerProfileSheetChrome(mode: viewModel.mode))
        .task {
            await viewModel.load()
        }
        .onChange(of: viewModel.didCompleteAction) { completed in
            if completed {
                handleClose()
            }
        }
    }

    private func handleClose() {
        onFinished()
        dismiss()
    }

    private func handleOpenChat(chatId: String, title: String) {
        dismiss()
        onOpenChat(chatId, title)
    }
}

/// Soft sheet corners; social keeps large detent, Liked You goes full height.
private struct PeerProfileSheetChrome: ViewModifier {
    let mode: PeerProfileMode

    func body(content: Content) -> some View {
        switch mode {
        case .social:
            content
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .modifier(SoftCornerRadius())
        case .likedYou:
            content
                .presentationDragIndicator(.visible)
                .modifier(SoftCornerRadius())
        }
    }
}

private struct SoftCornerRadius: ViewModifier {
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
        aboutMe: "Always up for a board game night and good coffee.",
        ageConfirmedAt: Date()
    )

    static func viewModel(
        mode: PeerProfileMode = .social,
        relationship: PeerRelationship = .none
    ) -> PeerProfileViewModel {
        let users = PreviewPeerUserRepository(user: sampleUser)
        let connections = StubConnectionRepository()
        let communities = StubCommunityRepository()

        switch relationship {
        case .none:
            connections.connection = nil
        case .pending:
            connections.connection = ConnectionRequest(
                id: "a_b",
                fromUserId: "me",
                toUserId: sampleUser.id,
                communityId: nil,
                status: .pending,
                createdAt: Date()
            )
        case .matched:
            connections.connection = ConnectionRequest(
                id: "a_b",
                fromUserId: "me",
                toUserId: sampleUser.id,
                communityId: nil,
                status: .accepted,
                createdAt: Date()
            )
        }

        return PeerProfileViewModel(
            userId: sampleUser.id,
            mode: mode,
            userRepository: users,
            connectionRepository: connections,
            communityRepository: communities,
            profilePostRepository: StubProfilePostRepository(),
            chatRepository: StubChatRepository()
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

#Preview("Social — Connect available") {
    PeerProfileSheet(previewViewModel: PeerProfilePreviewData.viewModel(relationship: .none))
}

#Preview("Social — Request sent") {
    PeerProfileSheet(previewViewModel: PeerProfilePreviewData.viewModel(relationship: .pending))
}

#Preview("Social — Matched / Remove") {
    PeerProfileSheet(previewViewModel: PeerProfilePreviewData.viewModel(relationship: .matched))
}

#Preview("Liked You") {
    PeerProfileSheet(
        previewViewModel: PeerProfilePreviewData.viewModel(
            mode: .likedYou(requestId: "req-1")
        )
    )
}
#endif
