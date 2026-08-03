import SwiftUI

struct ProfileView: View {
    @ObservedObject var viewModel: ProfileViewModel
    let makeSettingsViewModel: () -> SettingsViewModel
    let onSignOut: () -> Void

    @State private var isEditing = false
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                switch viewModel.state {
                case .idle, .loading:
                    ProgressView("Loading profile…")
                        .tint(CLColor.primary)
                        .foregroundStyle(CLColor.inkMuted)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .empty:
                    emptyState
                case let .error(message):
                    errorState(message: message)
                case let .loaded(user):
                    profileContent(user: user)
                }
            }
            .clCanvasBackground()
            .navigationTitle("Profile")
            .toolbar {
                if case .loaded = viewModel.state {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Edit") {
                            isEditing = true
                        }
                        .foregroundStyle(CLColor.primaryPressed)
                        .accessibilityLabel("Edit profile")
                    }
                }
            }
            .navigationDestination(isPresented: $isEditing) {
                ProfileEditView(viewModel: viewModel)
            }
            .navigationDestination(for: SettingsRoute.self) { _ in
                SettingsView(viewModel: makeSettingsViewModel())
            }
            .task {
                await viewModel.loadProfile()
            }
        }
    }

    @ViewBuilder
    private func profileContent(user: User) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                ProfileHeroView(
                    user: user,
                    localAvatarPreview: viewModel.localAvatarPreview
                )

                VStack(spacing: CLSpacing.xl) {
                    ProfilePublicCardView(
                        user: user,
                        localAvatarPreview: viewModel.localAvatarPreview
                    )

                    ProfileAccountSection(
                        onOpenSettings: { path.append(SettingsRoute()) },
                        onSignOut: onSignOut
                    )
                }
                .padding(.horizontal, CLSpacing.md)
                .padding(.top, CLSpacing.lg)
                .padding(.bottom, CLSpacing.xxl)
            }
            .clAppear()
        }
    }

    private var emptyState: some View {
        CLEmptyState(
            systemImage: "person.crop.circle.badge.exclamationmark",
            title: "Profile not found",
            actionTitle: "Retry",
            actionAccessibilityLabel: "Retry loading profile"
        ) {
            Task { await viewModel.loadProfile() }
        }
    }

    private func errorState(message: String) -> some View {
        CLEmptyState(
            systemImage: "exclamationmark.triangle",
            title: message,
            systemImageColor: CLColor.error,
            actionTitle: "Retry",
            actionAccessibilityLabel: "Retry loading profile",
            titleAccessibilityLabel: "Error: \(message)"
        ) {
            Task { await viewModel.loadProfile() }
        }
    }
}
