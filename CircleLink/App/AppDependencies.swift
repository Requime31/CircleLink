import Foundation

/// Composition root — creates and wires all app dependencies.
/// No Firebase / Keychain instances should be created outside this type.
@MainActor
final class AppDependencies {
    let appearanceStore: AppAppearanceStore
    let authRepository: AuthRepository
    let tokenStorage: SecureTokenStorage
    let userRepository: UserRepository
    let communityRepository: CommunityRepository
    let connectionRepository: ConnectionRepository
    let chatRepository: ChatRepository
    let moderationRepository: ModerationRepository
    let profilePostRepository: ProfilePostRepository
    let communityPostRepository: CommunityPostRepository
    let communityImageStorage: CommunityImageStorage
    let pushNotificationHandler: PushNotificationHandler
    let reminderScheduler: ReminderScheduling
    let reminderPreferencesStore: ConnectReminderPreferencesStoring
    let supportMailPresenter: SupportMailPresenting
    let supportMetadataProvider: SupportDeviceMetadataProviding
    let appRatingPresenter: AppRatingPresenting

    init(
        appearanceStore: AppAppearanceStore? = nil,
        authRepository: AuthRepository? = nil,
        tokenStorage: SecureTokenStorage? = nil,
        userRepository: UserRepository? = nil,
        communityRepository: CommunityRepository? = nil,
        connectionRepository: ConnectionRepository? = nil,
        chatRepository: ChatRepository? = nil,
        moderationRepository: ModerationRepository? = nil,
        profilePostRepository: ProfilePostRepository? = nil,
        communityPostRepository: CommunityPostRepository? = nil,
        communityImageStorage: CommunityImageStorage? = nil,
        pushNotificationHandler: PushNotificationHandler? = nil,
        reminderScheduler: ReminderScheduling? = nil,
        reminderPreferencesStore: ConnectReminderPreferencesStoring? = nil,
        supportMailPresenter: SupportMailPresenting? = nil,
        supportMetadataProvider: SupportDeviceMetadataProviding? = nil,
        appRatingPresenter: AppRatingPresenting? = nil
    ) {
        self.appearanceStore = appearanceStore ?? AppAppearanceStore()
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
        self.moderationRepository = moderationRepository ?? FirestoreModerationRepository()
        self.profilePostRepository = profilePostRepository ?? FirestoreProfilePostRepository(
            imageStorage: SupabaseProfileImageStorage()
        )
        let resolvedCommunityImageStorage = communityImageStorage ?? SupabaseCommunityImageStorage()
        self.communityImageStorage = resolvedCommunityImageStorage
        self.communityPostRepository = communityPostRepository ?? FirestoreCommunityPostRepository(
            imageStorage: resolvedCommunityImageStorage
        )
        self.pushNotificationHandler = pushNotificationHandler ?? PushNotificationHandler(
            userRepository: resolvedUserRepository,
            authRepository: self.authRepository
        )
        self.reminderScheduler = reminderScheduler ?? UserNotificationReminderScheduler()
        self.reminderPreferencesStore = reminderPreferencesStore ?? UserDefaultsConnectReminderPreferencesStore()
        self.supportMailPresenter = supportMailPresenter ?? SystemSupportMailPresenter()
        self.supportMetadataProvider = supportMetadataProvider ?? SystemSupportDeviceMetadataProvider()
        self.appRatingPresenter = appRatingPresenter ?? StoreKitAppRatingPresenter()
    }

    // MARK: - Session

    func restoreAuthenticatedProfile() async throws -> User? {
        if let firebaseAuth = authRepository as? FirebaseAuthRepository {
            return try await firebaseAuth.restoreSessionProfile()
        }
        return authRepository.currentUser
    }

    // MARK: - ViewModel factories

    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(
            pushHandler: pushNotificationHandler,
            reminderScheduler: reminderScheduler,
            reminderPreferencesStore: reminderPreferencesStore,
            appRatingPresenter: appRatingPresenter
        )
    }

    func makeSupportViewModel() -> SupportViewModel {
        SupportViewModel(
            mailPresenter: supportMailPresenter,
            metadataProvider: supportMetadataProvider
        )
    }

    func makeAuthViewModel(onAuthenticated: @escaping (User) -> Void) -> AuthViewModel {
        AuthViewModel(authRepository: authRepository, onAuthenticated: onAuthenticated)
    }

    func makeAccountDeletionViewModel(onDeactivated: @escaping (String) async -> Void) -> AccountDeletionViewModel {
        AccountDeletionViewModel(
            authRepository: authRepository,
            userRepository: userRepository,
            onDeactivated: onDeactivated
        )
    }

    func makeBlockedPeopleViewModel() -> BlockedPeopleViewModel {
        BlockedPeopleViewModel(
            moderationRepository: moderationRepository,
            userRepository: userRepository
        )
    }

    func makeAccountRecoveryViewModel(
        profile: User,
        onRestored: @escaping (User) -> Void,
        onSignOut: @escaping (String) async -> Void
    ) -> AccountRecoveryViewModel {
        AccountRecoveryViewModel(
            profile: profile,
            authRepository: authRepository,
            userRepository: userRepository,
            onRestored: onRestored,
            onSignOut: onSignOut
        )
    }

    func makeAgeGateViewModel(onAgeConfirmed: @escaping (User) -> Void) -> AgeGateViewModel {
        AgeGateViewModel(
            authRepository: authRepository,
            userRepository: userRepository,
            onAgeConfirmed: onAgeConfirmed
        )
    }

    func makeCommunitiesViewModel() -> CommunitiesViewModel {
        CommunitiesViewModel(
            communityRepository: communityRepository,
            communityImageStorage: communityImageStorage
        )
    }

    func makeCommunityDetailViewModel(communityId: String) -> CommunityDetailViewModel {
        CommunityDetailViewModel(
            communityId: communityId,
            communityRepository: communityRepository,
            chatRepository: chatRepository,
            authRepository: authRepository,
            communityPostRepository: communityPostRepository,
            communityImageStorage: communityImageStorage,
            userRepository: userRepository
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

    func makeConnectViewModel(
        onOpenChat: @escaping (String, String) -> Void = { _, _ in }
    ) -> ConnectViewModel {
        ConnectViewModel(
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
            communityRepository: communityRepository,
            connectionRepository: connectionRepository,
            profilePostRepository: profilePostRepository,
            onProfileSaved: onProfileSaved
        )
    }

    /// Peer profile sheet for all modes (social / likedYou / read-only).
    /// Sheet owns its ViewModel — prefer this over creating the VM in a `.sheet` closure.
    func makePeerProfileSheet(
        userId: String,
        mode: PeerProfileMode = .social,
        onBlocked: @escaping (String) -> Void = { _ in },
        onOpenChat: @escaping (String, String) -> Void = { _, _ in },
        onFinished: @escaping () -> Void = {}
    ) -> PeerProfileSheet {
        PeerProfileSheet(
            userId: userId,
            mode: mode,
            userRepository: userRepository,
            connectionRepository: connectionRepository,
            communityRepository: communityRepository,
            profilePostRepository: profilePostRepository,
            chatRepository: chatRepository,
            moderationRepository: moderationRepository,
            onBlocked: onBlocked,
            onOpenChat: onOpenChat,
            onFinished: onFinished
        )
    }

    /// Prefer `makePeerProfileSheet` for presentation. Use this when embedding `PeerProfileView` directly.
    func makePeerProfileViewModel(
        userId: String,
        mode: PeerProfileMode = .social
    ) -> PeerProfileViewModel {
        PeerProfileViewModel(
            userId: userId,
            mode: mode,
            userRepository: userRepository,
            connectionRepository: connectionRepository,
            communityRepository: communityRepository,
            profilePostRepository: profilePostRepository,
            chatRepository: chatRepository,
            moderationRepository: moderationRepository
        )
    }
}
