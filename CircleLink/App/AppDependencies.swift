import Foundation

/// Composition root — creates and wires all app dependencies.
/// No Firebase / Keychain instances should be created outside this type.
@MainActor
final class AppDependencies {
    let authRepository: AuthRepository
    let tokenStorage: SecureTokenStorage
    let userRepository: UserRepository
    let communityRepository: CommunityRepository
    let communityPostRepository: CommunityPostRepository
    let connectionRepository: ConnectionRepository
    let chatRepository: ChatRepository
    let moderationRepository: ModerationRepository
    let pushNotificationHandler: PushNotificationHandler

    init(
        authRepository: AuthRepository? = nil,
        tokenStorage: SecureTokenStorage? = nil,
        userRepository: UserRepository? = nil,
        communityRepository: CommunityRepository? = nil,
        communityPostRepository: CommunityPostRepository? = nil,
        connectionRepository: ConnectionRepository? = nil,
        chatRepository: ChatRepository? = nil,
        moderationRepository: ModerationRepository? = nil,
        pushNotificationHandler: PushNotificationHandler? = nil
    ) {
        let resolvedTokenStorage = tokenStorage ?? KeychainTokenStorage()
        let resolvedUserRepository = userRepository ?? FirestoreUserRepository()

        self.tokenStorage = resolvedTokenStorage
        self.userRepository = resolvedUserRepository
        self.authRepository = authRepository ?? FirebaseAuthRepository(
            tokenStorage: resolvedTokenStorage,
            userRepository: resolvedUserRepository,
            appleSignInPresenter: AppleSignInPresenter()
        )
        self.communityRepository = communityRepository ?? FirestoreCommunityRepository()
        self.communityPostRepository = communityPostRepository ?? FirestoreCommunityPostRepository(
            imageStorage: SupabaseCommunityImageStorage()
        )
        self.connectionRepository = connectionRepository ?? FirestoreConnectionRepository()
        let resolvedImageStorage = SupabaseChatImageStorage()
        self.chatRepository = chatRepository ?? FirestoreChatRepository(
            imageStorage: resolvedImageStorage
        )
        self.moderationRepository = moderationRepository ?? FirestoreModerationRepository()
        self.pushNotificationHandler = pushNotificationHandler ?? PushNotificationHandler(
            userRepository: resolvedUserRepository,
            authRepository: self.authRepository
        )
    }

    // MARK: - Session

    func restoreAuthenticatedProfile() async throws -> User? {
        try await authRepository.restoreSessionProfile()
    }

    // MARK: - ViewModel factories

    func makeAuthViewModel(onAuthenticated: @escaping (User) -> Void) -> AuthViewModel {
        AuthViewModel(authRepository: authRepository, onAuthenticated: onAuthenticated)
    }

    func makeAgeGateViewModel(onAgeConfirmed: @escaping (User) -> Void) -> AgeGateViewModel {
        AgeGateViewModel(
            confirmAge: ConfirmAgeUseCase(
                userRepository: userRepository,
                authRepository: authRepository
            ),
            onAgeConfirmed: onAgeConfirmed
        )
    }

    func makeCommunitiesViewModel() -> CommunitiesViewModel {
        CommunitiesViewModel(communityRepository: communityRepository)
    }

    func makeCommunityDetailViewModel(communityId: String) -> CommunityDetailViewModel {
        CommunityDetailViewModel(
            communityId: communityId,
            communityRepository: communityRepository,
            authRepository: authRepository,
            leaveCommunity: LeaveCommunityUseCase(
                chatRepository: chatRepository,
                communityRepository: communityRepository
            ),
            openCommunityChat: OpenCommunityChatUseCase(
                communityRepository: communityRepository,
                chatRepository: chatRepository,
                authRepository: authRepository
            )
        )
    }

    func makeCommunityFeedViewModel(communityId: String) -> CommunityFeedViewModel {
        CommunityFeedViewModel(
            communityId: communityId,
            postRepository: communityPostRepository,
            userRepository: userRepository,
            authRepository: authRepository
        )
    }

    func makeChatsViewModel() -> ChatsViewModel {
        ChatsViewModel(
            chatRepository: chatRepository,
            currentUserId: authRepository.currentUser?.id ?? ""
        )
    }

    func makeChatInfoViewModel(chatId: String) -> ChatInfoViewModel {
        ChatInfoViewModel(
            chatId: chatId,
            currentUserId: authRepository.currentUser?.id ?? "",
            chatRepository: chatRepository
        )
    }

    func makeChatViewModel(
        chatId: String,
        title: String = "Chat",
        onPeerBlocked: (() -> Void)? = nil
    ) -> ChatViewModel? {
        guard let currentUserId = authRepository.currentUser?.id else { return nil }
        let peerUserId = DirectChatPeer.peerUserId(chatId: chatId, currentUserId: currentUserId)
        return ChatViewModel(
            chatId: chatId,
            currentUserId: currentUserId,
            chatRepository: chatRepository,
            chatTitle: title,
            peerUserId: peerUserId,
            moderationRepository: peerUserId == nil ? nil : moderationRepository,
            onPeerBlocked: onPeerBlocked
        )
    }

    func makeConnectTabModel(onOpenChat: @escaping (String) -> Void = { _ in }) -> ConnectTabModel {
        ConnectTabModel(
            connectionRepository: connectionRepository,
            chatRepository: chatRepository,
            communityRepository: communityRepository,
            userRepository: userRepository,
            authRepository: authRepository,
            moderationRepository: moderationRepository,
            onOpenChat: onOpenChat
        )
    }

    func makeProfileViewModel(onProfileSaved: ((User) -> Void)? = nil) -> ProfileViewModel {
        ProfileViewModel(
            authRepository: authRepository,
            userRepository: userRepository,
            onProfileSaved: onProfileSaved
        )
    }

    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(notificationSettings: pushNotificationHandler)
    }

    /// Peer (other user) profile sheet. Pass `communityId` when known so Connect works.
    /// Sheet owns its ViewModel — prefer this over creating the VM in a `.sheet` closure.
    func makePeerProfileSheet(
        userId: String,
        communityId: String? = nil
    ) -> PeerProfileSheet {
        PeerProfileSheet(
            userId: userId,
            communityId: communityId,
            userRepository: userRepository,
            connectionRepository: connectionRepository
        )
    }

    /// Prefer `makePeerProfileSheet` for presentation. Use this when embedding `PeerProfileView` directly.
    func makePeerProfileViewModel(
        userId: String,
        communityId: String? = nil
    ) -> PeerProfileViewModel {
        PeerProfileViewModel(
            userId: userId,
            communityId: communityId,
            userRepository: userRepository,
            connectionRepository: connectionRepository
        )
    }
}
