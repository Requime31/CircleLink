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
    private var openChatTask: Task<Void, Never>?
    /// Bumped to ignore stale metadata fetches after a newer open-chat / non-chat route.
    private var openChatGeneration = 0

    private let communitiesViewModel: CommunitiesViewModel
    private let chatsViewModel: ChatsViewModel
    private let profileViewModel: ProfileViewModel

    private lazy var connectTabModel: ConnectTabModel = dependencies.makeConnectTabModel { [weak self] chatId in
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
                    connectTabModel: connectTabModel,
                    profileViewModel: profileViewModel,
                    makeCommunityDetailViewModel: dependencies.makeCommunityDetailViewModel,
                    makeCommunityFeedViewModel: dependencies.makeCommunityFeedViewModel,
                    makeChatViewModel: { chatId, title in
                        self.dependencies.makeChatViewModel(chatId: chatId, title: title)
                    },
                    makeChatInfoViewModel: dependencies.makeChatInfoViewModel,
                    makePeerProfileSheet: dependencies.makePeerProfileSheet,
                    makeSettingsViewModel: dependencies.makeSettingsViewModel,
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
        cancelOpenChatWork()
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
        connectTabModel.resetForm()
        route = .auth
    }

    func signOut() {
        Task { @MainActor in
            await dependencies.pushNotificationHandler.clearTokenOnSignOut()
            do {
                try await dependencies.authRepository.signOut()
                handleSignedOut()
            } catch {
                #if DEBUG
                print("[AppCoordinator] signOut failed: \(error.localizedDescription)")
                #endif
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
                openChat(chatId: chatId)
            } else {
                cancelOpenChatWork()
                pendingChatRoute = nil
                selectedTab = .chats
            }

        case .connectionRequest:
            cancelOpenChatWork()
            pendingChatRoute = nil
            selectedTab = .connect

        case .connectionAccepted:
            // Open Connect (not Chat) so we never create/mutate a chat as a side effect
            // of a tap before `createDirectChat` has finished on the acceptor device.
            cancelOpenChatWork()
            pendingChatRoute = nil
            selectedTab = .connect
        }
    }

    // MARK: - Navigation callbacks

    func onChatSelected(chatId: String) {
        openChat(chatId: chatId)
    }

    func onCommunitySelected(communityId: String) {
        // Hook reserved for analytics / deep-link context (Phase 14+: no debug noise).
        _ = communityId
    }

    /// Group chat entry — `chatId` is a real Firestore id from `createGroupChat`.
    func onOpenGroupChat(chatId: String, title: String) {
        openChat(chatId: chatId, knownTitle: title)
    }

    /// Opens a chat without reading `ChatsViewModel` list state.
    /// Sets `pendingChatRoute` immediately, then refines title/`communityId` from the repository
    /// only while that pending route is still unconsumed (avoids clobbering later navigation).
    private func openChat(chatId: String, knownTitle: String? = nil) {
        selectedTab = .chats
        openChatTask?.cancel()
        openChatGeneration += 1
        let generation = openChatGeneration

        pendingChatRoute = ChatThreadRouteBuilder.make(
            chatId: chatId,
            title: knownTitle,
            communityId: nil
        )

        openChatTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                if generation == self.openChatGeneration {
                    self.openChatTask = nil
                }
            }

            do {
                let metadata = try await self.dependencies.chatRepository
                    .fetchChatThreadMetadata(chatId: chatId)
                guard !Task.isCancelled, generation == self.openChatGeneration else { return }
                // ChatList clears pending once consumed — do not re-push a stale route.
                guard self.pendingChatRoute?.chatId == chatId else { return }

                let title: String?
                if let knownTitle, !knownTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    title = knownTitle
                } else {
                    title = metadata.title
                }

                self.pendingChatRoute = ChatThreadRouteBuilder.make(
                    chatId: chatId,
                    title: title,
                    communityId: metadata.communityId
                )
            } catch is CancellationError {
                return
            } catch {
                // Already opened with known/default title; communityId stays nil.
                return
            }
        }
    }

    private func cancelOpenChatWork() {
        openChatTask?.cancel()
        openChatTask = nil
        openChatGeneration += 1
    }
}
