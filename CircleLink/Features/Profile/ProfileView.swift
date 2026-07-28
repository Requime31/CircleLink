import SwiftUI

struct ProfileView: View {
    @ObservedObject var viewModel: ProfileViewModel
    let onSignOut: () -> Void

    @State private var isEditing = false

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .idle, .loading:
                    ProgressView("Loading profile…")
                        .tint(CLColor.primary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .empty:
                    emptyState
                case let .error(message):
                    errorState(message: message)
                case let .loaded(user):
                    profileContent(user: user)
                }
            }
            .background(CLColor.canvas)
            .navigationTitle("Profile")
            .toolbar {
                if case .loaded = viewModel.state {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Edit") {
                            isEditing = true
                        }
                        .foregroundStyle(CLColor.primary)
                        .accessibilityLabel("Edit profile")
                    }
                }
            }
            .navigationDestination(isPresented: $isEditing) {
                ProfileEditView(viewModel: viewModel)
            }
            .task {
                await viewModel.loadProfile()
            }
        }
    }

    @ViewBuilder
    private func profileContent(user: User) -> some View {
        ScrollView {
            VStack(spacing: CLSpacing.lg) {
                AvatarImageView(
                    localPreview: viewModel.localAvatarPreview,
                    avatarBase64: user.avatarBase64,
                    avatarURL: user.avatarURL,
                    size: 120
                )
                .accessibilityLabel("Profile photo")

                VStack(spacing: CLSpacing.xs) {
                    Text(user.displayName)
                        .font(CLTypography.title2)
                        .foregroundStyle(CLColor.ink)
                        .accessibilityLabel("Display name: \(user.displayName)")

                    if user.interests.isEmpty {
                        Text("No interests yet")
                            .font(CLTypography.callout)
                            .foregroundStyle(CLColor.muted)
                    }
                }

                if !user.interests.isEmpty {
                    VStack(alignment: .leading, spacing: CLSpacing.sm) {
                        Text("Interests")
                            .font(CLTypography.section)
                            .foregroundStyle(CLColor.ink)

                        FlowLayout(spacing: CLSpacing.sm) {
                            ForEach(user.interests, id: \.self) { interest in
                                Text(interest)
                                    .font(CLTypography.callout)
                                    .foregroundStyle(CLColor.ink)
                                    .padding(.horizontal, CLSpacing.md)
                                    .padding(.vertical, CLSpacing.sm)
                                    .background(CLColor.surfaceSoft)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                LogoutButton(action: onSignOut)
                    .padding(.top, CLSpacing.base)
            }
            .padding(CLSpacing.lg)
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
            actionTitle: "Retry",
            actionAccessibilityLabel: "Retry loading profile",
            titleAccessibilityLabel: "Error: \(message)"
        ) {
            Task { await viewModel.loadProfile() }
        }
    }
}
