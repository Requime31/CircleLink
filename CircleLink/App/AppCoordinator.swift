import Combine
import SwiftUI

/// Owns root navigation and forwards deep-link / selection callbacks.
@MainActor
final class AppCoordinator: ObservableObject {
    enum Route: Equatable {
        case bootstrapping
        case auth
        case accountRecovery
        case ageGate
        case profileSetup
        case mainTab
    }

    enum MainTab: Hashable {
        case communities
        case chats
        case connect
        case profile
    }

    @Published private(set) var route: Route
    @Published private(set) var currentProfile: User?
    /// External entry (Connect / community / deep link) → Chats tab pushes this route.
    @Published var pendingChatRoute: ChatThreadRoute?
    @Published var selectedTab: MainTab = .communities

    private let dependencies: AppDependencies
    private var pendingDeepLink: PushDeepLink?

    private let communitiesViewModel: CommunitiesViewModel
    private let chatsViewModel: ChatsViewModel
    private let profileViewModel: ProfileViewModel
    private var accountRecoveryViewModel: AccountRecoveryViewModel?

    private lazy var connectViewModel: ConnectViewModel = dependencies.makeConnectViewModel { [weak self] chatId, title in
        self?.openDirectChat(chatId: chatId, title: title)
    }

    private lazy var authViewModel = dependencies.makeAuthViewModel { [weak self] user in
        self?.handleAuthenticated(user: user)
    }

    private lazy var ageGateViewModel = dependencies.makeAgeGateViewModel { [weak self] user in
        self?.handleAgeConfirmed(user: user)
    }

    private lazy var profileSetupViewModel = dependencies.makeProfileViewModel { [weak self] user in
        self?.handleProfileSaved(user: user)
    }

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies

        if dependencies.authRepository.currentUser == nil {
            route = .auth
        } else {
            route = .bootstrapping
        }

        self.communitiesViewModel = dependencies.makeCommunitiesViewModel()
        self.chatsViewModel = dependencies.makeChatsViewModel()
        self.profileViewModel = dependencies.makeProfileViewModel()

        dependencies.pushNotificationHandler.onDeepLink = { [weak self] deepLink in
            self?.handleDeepLink(deepLink)
        }
    }

    /// Wires AppDelegate → PushNotificationHandler (call once from app entry).
    func attachPushHandling(to appDelegate: AppDelegate) {
        appDelegate.attach(pushHandler: dependencies.pushNotificationHandler)
    }

    @ViewBuilder
    var rootView: some View {
        Group {
            switch route {
            case .bootstrapping:
                LoadingView()
            case .auth:
                NavigationStack {
                    AuthView(viewModel: authViewModel)
                }
            case .accountRecovery:
                if let accountRecoveryViewModel {
                    AccountRecoveryView(viewModel: accountRecoveryViewModel)
                } else {
                    ProgressView("Loading…")
                }
            case .ageGate:
                NavigationStack {
                    AgeGateView(
                        viewModel: ageGateViewModel,
                        onSignOut: signOut
                    )
                }
            case .profileSetup:
                NavigationStack {
                    ProfileSetupView(
                        viewModel: profileSetupViewModel,
                        onSignOut: signOut
                    )
                }
            case .mainTab:
                MainTabView(
                    selectedTab: Binding(
                        get: { self.selectedTab },
                        set: { self.selectedTab = $0 }
                    ),
                    pendingChatRoute: Binding(
                        get: { self.pendingChatRoute },
                        set: { self.pendingChatRoute = $0 }
                    ),
                    communitiesViewModel: communitiesViewModel,
                    chatsViewModel: chatsViewModel,
                    connectViewModel: connectViewModel,
                    profileViewModel: profileViewModel,
                    makeCommunityDetailViewModel: dependencies.makeCommunityDetailViewModel,
                    makeChatViewModel: { chatId, title in
                        self.dependencies.makeChatViewModel(
                            chatId: chatId,
                            title: title,
                            onPeerBlocked: { [weak self] in
                                guard let self,
                                      let peerId = DirectChatPeer.peerUserId(
                                        chatId: chatId,
                                        currentUserId: self.dependencies.authRepository.currentUser?.id ?? ""
                                      ) else { return }
                                self.connectViewModel.handlePeerBlocked(userId: peerId)
                            }
                        )
                    },
                    makeChatInfoViewModel: dependencies.makeChatInfoViewModel,
                    makePeerProfileSheet: { userId, mode in
                        self.dependencies.makePeerProfileSheet(
                            userId: userId,
                            mode: mode,
                            onBlocked: { [weak self] blockedId in
                                self?.connectViewModel.handlePeerBlocked(userId: blockedId)
                            },
                            onOpenChat: self.openDirectChat
                        )
                    },
                    makeSettingsViewModel: dependencies.makeSettingsViewModel,
                    makeSupportViewModel: dependencies.makeSupportViewModel,
                    onCommunitySelected: onCommunitySelected,
                    onOpenGroupChat: onOpenGroupChat,
                    onSignOut: signOut,
                    makeAccountDeletionViewModel: {
                        return self.dependencies.makeAccountDeletionViewModel {
                            await self.performSignOut(expectedUserID: $0)
                        }
                    },
                    makeBlockedPeopleViewModel: dependencies.makeBlockedPeopleViewModel
                )
            }
        }
        .task {
            await self.bootstrapIfNeeded()
        }
    }

    // MARK: - Bootstrap

    func bootstrapIfNeeded() async {
        guard route == .bootstrapping else { return }

        #if DEBUG
        // Keep the branded loading animation visible during local development.
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        #endif

        do {
            if let profile = try await dependencies.restoreAuthenticatedProfile() {
                applyRoute(for: profile)
                return
            }
        } catch {
            route = .auth
            return
        }

        guard let user = dependencies.authRepository.currentUser else {
            route = .auth
            return
        }

        do {
            let profile = try await dependencies.userRepository.fetchProfile(userId: user.id)
            applyRoute(for: profile)
        } catch {
            route = .auth
        }
    }

    // MARK: - Route updates

    func handleAuthenticated(user: User) {
        currentProfile = user
        applyRoute(for: user)
    }

    func handleAgeConfirmed(user: User) {
        currentProfile = user
        applyRoute(for: user)
    }

    func handleProfileSaved(user: User) {
        currentProfile = user
        applyRoute(for: user)
    }

    func handleSignedOut() {
        currentProfile = nil
        accountRecoveryViewModel = nil
        pendingDeepLink = nil
        pendingChatRoute = nil
        selectedTab = .communities
        authViewModel.resetForm()
        ageGateViewModel.resetForm()
        profileSetupViewModel.resetForm()
        profileViewModel.resetForm()
        communitiesViewModel.resetForm()
        chatsViewModel.resetForm()
        connectViewModel.resetForm()
        route = .auth
    }

    func signOut() {
        Task { @MainActor in
            guard let userID = dependencies.authRepository.currentUser?.id else { return }
            await performSignOut(expectedUserID: userID)
        }
    }

    func performSignOut(expectedUserID: String) async {
        guard dependencies.authRepository.currentUser?.id == expectedUserID else { return }
        await dependencies.pushNotificationHandler.clearTokenOnSignOut()
        guard dependencies.authRepository.currentUser?.id == expectedUserID else { return }
        do {
            try dependencies.authRepository.signOut()
            handleSignedOut()
        } catch {
            if dependencies.authRepository.currentUser == nil {
                handleSignedOut()
                return
            }
            #if DEBUG
            print("[AppCoordinator] signOut failed: \(error.localizedDescription)")
            #endif
        }
    }

    private func applyRoute(for user: User) {
        currentProfile = user

        if Self.route(for: user) == .accountRecovery {
            pendingDeepLink = nil
            pendingChatRoute = nil
            accountRecoveryViewModel = dependencies.makeAccountRecoveryViewModel(
                profile: user,
                onRestored: { [weak self] restored in self?.applyRoute(for: restored) },
                onSignOut: { [weak self] userID in await self?.performSignOut(expectedUserID: userID) }
            )
            route = .accountRecovery
        } else if user.ageConfirmedAt == nil {
            accountRecoveryViewModel = nil
            route = .ageGate
        } else if !user.isProfileComplete {
            accountRecoveryViewModel = nil
            route = .profileSetup
        } else {
            accountRecoveryViewModel = nil
            route = .mainTab
            applyPendingDeepLinkIfNeeded()
            // Permission after auth + onboarding — not on cold launch, not buried in Send/Connect.
            Task { await dependencies.pushNotificationHandler.requestPermissionIfNeeded() }
        }
    }

    static func route(for user: User) -> Route {
        if user.accountState == .deactivated { return .accountRecovery }
        if user.ageConfirmedAt == nil { return .ageGate }
        if !user.isProfileComplete { return .profileSetup }
        return .mainTab
    }

    // MARK: - Deep links (push only — routed here)

    func handleDeepLink(_ deepLink: PushDeepLink) {
        guard isDeepLinkAllowed(deepLink) else { return }

        guard route == .mainTab else {
            pendingDeepLink = deepLink
            return
        }
        apply(deepLink)
    }

    private func isDeepLinkAllowed(_ deepLink: PushDeepLink) -> Bool {
        guard let targetUserId = deepLink.targetUserId else {
            // Older payloads without targetUserId — only apply when signed in on mainTab later.
            return dependencies.authRepository.currentUser != nil
        }
        return dependencies.authRepository.currentUser?.id == targetUserId
    }

    private func applyPendingDeepLinkIfNeeded() {
        guard let pendingDeepLink else { return }
        self.pendingDeepLink = nil
        guard isDeepLinkAllowed(pendingDeepLink) else { return }
        apply(pendingDeepLink)
    }

    private func apply(_ deepLink: PushDeepLink) {
        switch deepLink.kind {
        case .newMessage:
            if let chatId = deepLink.chatId {
                selectedTab = .chats
                openChat(chatId: chatId, title: chatTitle(for: chatId))
            } else {
                selectedTab = .chats
            }

        case .connectionRequest:
            selectedTab = .connect

        case .connectionAccepted:
            // Open Connect (not Chat) so we never create/mutate a chat as a side effect
            // of a tap before `createDirectChat` has finished on the acceptor device.
            selectedTab = .connect
        }
    }

    // MARK: - Navigation callbacks

    func onChatSelected(chatId: String) {
        openChat(chatId: chatId, title: chatTitle(for: chatId))
    }

    func onCommunitySelected(communityId: String) {
        // Hook reserved for analytics / deep-link context (Phase 14+: no debug noise).
        _ = communityId
    }

    /// Group chat entry — `chatId` is a real Firestore id from `createGroupChat`.
    func onOpenGroupChat(chatId: String, title: String) {
        let prefix = "group_"
        guard chatId.hasPrefix(prefix) else {
            openChat(chatId: chatId, title: title)
            return
        }
        let communityId = String(chatId.dropFirst(prefix.count))
        guard !communityId.isEmpty else {
            openChat(chatId: chatId, title: title)
            return
        }
        selectedTab = .chats
        pendingChatRoute = .group(
            chatId: chatId,
            title: title,
            communityId: communityId
        )
    }

    /// Match/profile entry has already created a deterministic direct chat.
    /// Never enrich this route with community context from a cached summary.
    func openDirectChat(chatId: String, title: String) {
        selectedTab = .chats
        pendingChatRoute = .direct(chatId: chatId, title: title)
    }

    private func openChat(chatId: String, title: String) {
        selectedTab = .chats
        let communityId: String?
        if case let .loaded(chats) = chatsViewModel.state,
           let match = chats.first(where: { $0.id == chatId }) {
            communityId = match.communityId
        } else {
            communityId = nil
        }
        if let communityId {
            pendingChatRoute = .group(chatId: chatId, title: title, communityId: communityId)
        } else {
            pendingChatRoute = .direct(chatId: chatId, title: title)
        }
    }

    private func chatTitle(for chatId: String) -> String {
        if case let .loaded(chats) = chatsViewModel.state,
           let match = chats.first(where: { $0.id == chatId }) {
            return match.title
        }
        return "Chat"
    }
}
