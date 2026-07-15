import Foundation

/// Composition root — creates and wires all app dependencies.
/// No Firebase / Keychain / WebSocket instances should be created outside this type.
@MainActor
final class AppDependencies {
    let authRepository: AuthRepository
    let tokenStorage: SecureTokenStorage
    let userRepository: UserRepository
    let communityRepository: CommunityRepository
    let connectionRepository: ConnectionRepository
    let chatRepository: ChatRepository
    let webSocketClient: WebSocketClientProtocol
    let webSocketConnectionManager: WebSocketConnectionManager
    let pushNotificationHandler: PushNotificationHandler

    init(
        authRepository: AuthRepository? = nil,
        tokenStorage: SecureTokenStorage? = nil,
        userRepository: UserRepository? = nil,
        communityRepository: CommunityRepository? = nil,
        connectionRepository: ConnectionRepository? = nil,
        chatRepository: ChatRepository? = nil,
        webSocketClient: WebSocketClientProtocol? = nil,
        webSocketConnectionManager: WebSocketConnectionManager? = nil,
        pushNotificationHandler: PushNotificationHandler? = nil
    ) {
        let resolvedTokenStorage = tokenStorage ?? KeychainTokenStorage()
        let resolvedUserRepository = userRepository ?? FirestoreUserRepository()
        let resolvedWebSocketClient = webSocketClient ?? WebSocketClient()

        self.tokenStorage = resolvedTokenStorage
        self.userRepository = resolvedUserRepository
        self.authRepository = authRepository ?? FirebaseAuthRepository(
            tokenStorage: resolvedTokenStorage,
            userRepository: resolvedUserRepository,
            appleSignInPresenter: AppleSignInPresenter()
        )
        self.communityRepository = communityRepository ?? StubCommunityRepository()
        self.connectionRepository = connectionRepository ?? StubConnectionRepository()
        self.chatRepository = chatRepository ?? StubChatRepository()
        self.webSocketClient = resolvedWebSocketClient
        self.webSocketConnectionManager = webSocketConnectionManager ?? WebSocketConnectionManager(
            client: resolvedWebSocketClient,
            tokenProvider: FirebaseIDTokenProvider(),
            tokenStorage: resolvedTokenStorage
        )
        self.pushNotificationHandler = pushNotificationHandler ?? PushNotificationHandler()
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

    func makeChatsViewModel() -> ChatsViewModel {
        ChatsViewModel(chatRepository: chatRepository)
    }

    func makeConnectViewModel() -> ConnectViewModel {
        ConnectViewModel(connectionRepository: connectionRepository)
    }

    func makeProfileViewModel(onProfileSaved: ((User) -> Void)? = nil) -> ProfileViewModel {
        ProfileViewModel(
            authRepository: authRepository,
            userRepository: userRepository,
            onProfileSaved: onProfileSaved
        )
    }
}
