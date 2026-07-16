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

    @Published private(set) var route: Route
    @Published private(set) var currentProfile: User?
    @Published var presentedChatId: String?

    /// Temporary Phase 6 debug chat — replace with real chat creation in Phase 8.
    static let debugChatId = "debug-chat"

    private let dependencies: AppDependencies

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
                    communitiesViewModel: communitiesViewModel,
                    chatsViewModel: chatsViewModel,
                    connectViewModel: connectViewModel,
                    profileViewModel: profileViewModel,
                    makeCommunityDetailViewModel: dependencies.makeCommunityDetailViewModel,
                    onChatSelected: onChatSelected,
                    onCommunitySelected: onCommunitySelected,
                    onOpenGroupChat: onOpenGroupChat,
                    onOpenDebugChat: openDebugChat,
                    onSignOut: signOut
                )
            }
        }
        .task {
            await self.bootstrapIfNeeded()
        }
        .sheet(isPresented: Binding(
            get: { self.presentedChatId != nil },
            set: { if !$0 { self.dismissChat() } }
        )) {
            if let chatId = self.presentedChatId,
               let chatViewModel = self.dependencies.makeChatViewModel(chatId: chatId) {
                NavigationStack {
                    ChatViewControllerWrapper(viewModel: chatViewModel)
                        .ignoresSafeArea(.keyboard, edges: .bottom)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Close") {
                                    self.dismissChat()
                                }
                            }
                        }
                }
            } else {
                Text("Unable to open chat.")
            }
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
        do {
            try dependencies.authRepository.signOut()
            handleSignedOut()
        } catch {
            print("[AppCoordinator] signOut failed: \(error.localizedDescription)")
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
        }
    }

    // MARK: - Navigation callbacks (stubs for future phases)

    func onChatSelected(chatId: String) {
        presentedChatId = chatId
    }

    func dismissChat() {
        presentedChatId = nil
        Task { await chatsViewModel.loadChats() }
    }

    func onCommunitySelected(communityId: String) {
        print("[AppCoordinator] onCommunitySelected: \(communityId)")
    }

    func onOpenGroupChat(communityId: String) {
        presentedChatId = "group-\(communityId)"
    }

    func openDebugChat() {
        presentedChatId = Self.debugChatId
    }
}
