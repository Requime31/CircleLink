import Foundation

/// Composition root — creates and wires all app dependencies.
/// No Firebase / Keychain instances should be created outside this type.
@MainActor
final class AppDependencies {
    let authRepository: AuthRepository
    let tokenStorage: SecureTokenStorage
    let userRepository: UserRepository
    let communityRepository: CommunityRepository
    let connectionRepository: ConnectionRepository
    let chatRepository: ChatRepository
    let pushNotificationHandler: PushNotificationHandler

    init(
        authRepository: AuthRepository? = nil,
        tokenStorage: SecureTokenStorage? = nil,
        userRepository: UserRepository? = nil,
        communityRepository: CommunityRepository? = nil,
        connectionRepository: ConnectionRepository? = nil,
        chatRepository: ChatRepository? = nil,
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
        self.connectionRepository = connectionRepository ?? FirestoreConnectionRepository()
        let resolvedImageStorage = SupabaseChatImageStorage()
        self.chatRepository = chatRepository ?? FirestoreChatRepository(
            imageStorage: resolvedImageStorage
        )
        self.pushNotificationHandler = pushNotificationHandler ?? PushNotificationHandler(
            userRepository: resolvedUserRepository,
            authRepository: self.authRepository
        )
    }

    // MARK: - Session

    func restoreAuthenticatedProfile() async throws -> User? {
        if let firebaseAuth = authRepository as? FirebaseAuthRepository {
            return try await firebaseAuth.restoreSessionProfile()
        }
        return authRepository.currentUser
    }

    // MARK: - ViewModel factories

    func makeAuthViewModel(onAuthenticated: @escaping (User) -> Void) -> AuthViewModel {
        AuthViewModel(authRepository: authRepository, onAuthenticated: onAuthenticated)
    }

    func makeAgeGateViewModel(onAgeConfirmed: @escaping (User) -> Void) -> AgeGateViewModel {
        AgeGateViewModel(
            authRepository: authRepository,
            userRepository: userRepository,
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
            chatRepository: chatRepository,
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

    func makeChatViewModel(chatId: String, title: String = "Chat") -> ChatViewModel? {
        guard let currentUserId = authRepository.currentUser?.id else { return nil }
        return ChatViewModel(
            chatId: chatId,
            currentUserId: currentUserId,
            chatRepository: chatRepository,
            chatTitle: title
        )
    }

    func makeConnectViewModel(onOpenChat: @escaping (String) -> Void = { _ in }) -> ConnectViewModel {
        ConnectViewModel(
            connectionRepository: connectionRepository,
            chatRepository: chatRepository,
            communityRepository: communityRepository,
            userRepository: userRepository,
            authRepository: authRepository,
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
