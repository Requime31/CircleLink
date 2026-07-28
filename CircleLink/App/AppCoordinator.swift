import Combine
import SwiftUI

/// Owns root navigation and forwards deep-link / selection callbacks.
@MainActor
final class AppCoordinator: ObservableObject {
    enum Route: Equatable {
        case bootstrapping
        case auth
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

    private lazy var connectViewModel: ConnectViewModel = dependencies.makeConnectViewModel { [weak self] chatId in
        self?.onChatSelected(chatId: chatId)
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
                ProgressView("Loading…")
            case .auth:
                NavigationStack {
                    AuthView(viewModel: authViewModel)
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
                        self.dependencies.makeChatViewModel(chatId: chatId, title: title)
                    },
                    makeChatInfoViewModel: dependencies.makeChatInfoViewModel,
                    makePeerProfileSheet: dependencies.makePeerProfileSheet,
                    onCommunitySelected: onCommunitySelected,
                    onOpenGroupChat: onOpenGroupChat,
                    onSignOut: signOut
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
            await dependencies.pushNotificationHandler.clearTokenOnSignOut()
            do {
                try dependencies.authRepository.signOut()
                handleSignedOut()
            } catch {
                print("[AppCoordinator] signOut failed: \(error.localizedDescription)")
            }
        }
    }

    private func applyRoute(for user: User) {
        currentProfile = user

        if user.ageConfirmedAt == nil {
            route = .ageGate
        } else if !user.isProfileComplete {
            route = .profileSetup
        } else {
            route = .mainTab
            applyPendingDeepLinkIfNeeded()
            // Permission after auth + onboarding — not on cold launch, not buried in Send/Connect.
            Task { await dependencies.pushNotificationHandler.requestPermissionIfNeeded() }
        }
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
        print("[AppCoordinator] onCommunitySelected: \(communityId)")
    }

    /// Group chat entry — `chatId` is a real Firestore id from `createGroupChat`.
    func onOpenGroupChat(chatId: String, title: String) {
        openChat(chatId: chatId, title: title)
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
        pendingChatRoute = ChatThreadRoute(
            chatId: chatId,
            title: title,
            communityId: communityId
        )
    }

    private func chatTitle(for chatId: String) -> String {
        if case let .loaded(chats) = chatsViewModel.state,
           let match = chats.first(where: { $0.id == chatId }) {
            return match.title
        }
        return "Chat"
    }
}
