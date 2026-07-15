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

    private let dependencies: AppDependencies

    private let communitiesViewModel: CommunitiesViewModel
    private let chatsViewModel: ChatsViewModel
    private let connectViewModel: ConnectViewModel
    private let profileViewModel: ProfileViewModel

    private lazy var authViewModel = dependencies.makeAuthViewModel { [weak self] user in
        self?.handleAuthenticated(user: user)
    }

    private lazy var ageGateViewModel = dependencies.makeAgeGateViewModel { [weak self] user in
        self?.handleAgeConfirmed(user: user)
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
        self.connectViewModel = dependencies.makeConnectViewModel()
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
                    ProfileSetupPlaceholderView(onSignOut: signOut)
                }
            case .mainTab:
                MainTabView(
                    communitiesViewModel: communitiesViewModel,
                    chatsViewModel: chatsViewModel,
                    connectViewModel: connectViewModel,
                    profileViewModel: profileViewModel,
                    onChatSelected: onChatSelected,
                    onCommunitySelected: onCommunitySelected,
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

    func handleSignedOut() {
        currentProfile = nil
        authViewModel.resetForm()
        ageGateViewModel.resetForm()
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
        print("[AppCoordinator] onChatSelected: \(chatId)")
    }

    func onCommunitySelected(communityId: String) {
        print("[AppCoordinator] onCommunitySelected: \(communityId)")
    }
}
