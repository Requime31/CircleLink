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

                VStack(spacing: CLSpacing.xxs) {
                    Text(user.displayName)
                        .font(CLTypography.title)
                        .foregroundStyle(CLColor.ink)
                        .accessibilityLabel("Display name: \(user.displayName)")

                    if user.interests.isEmpty {
                        Text("No interests yet")
                            .font(CLTypography.subheadline)
                            .foregroundStyle(CLColor.inkMuted)
                    }
                }

                if !user.interests.isEmpty {
                    VStack(alignment: .leading, spacing: CLSpacing.xs) {
                        Text("Interests")
                            .font(CLTypography.headline)
                            .foregroundStyle(CLColor.ink)

                        FlowLayout(spacing: CLSpacing.xs) {
                            ForEach(user.interests, id: \.self) { interest in
                                Text(interest)
                                    .font(CLTypography.subheadline)
                                    .foregroundStyle(CLColor.inkSecondary)
                                    .padding(.horizontal, CLSpacing.sm)
                                    .padding(.vertical, CLSpacing.xs)
                                    .background(CLColor.surfaceSoft)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                LogoutButton(action: onSignOut)
                    .padding(.top, CLSpacing.md)
            }
            .padding(CLSpacing.lg)
            .clAppear()
        }
    }

    private var emptyState: some View {
        VStack(spacing: CLSpacing.sm) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(CLColor.inkMuted)
                .padding(CLSpacing.md)
                .background(Circle().fill(CLColor.primarySoft))
                .accessibilityHidden(true)
            Text("Profile not found")
                .font(CLTypography.title2)
                .foregroundStyle(CLColor.ink)
            Button("Retry") {
                Task { await viewModel.loadProfile() }
            }
            .buttonStyle(CLSecondaryButtonStyle())
            .padding(.top, CLSpacing.xs)
            .accessibilityLabel("Retry loading profile")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: CLSpacing.sm) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(CLColor.error)
                .padding(CLSpacing.md)
                .background(Circle().fill(CLColor.errorSoft))
                .accessibilityHidden(true)
            Text(message)
                .font(CLTypography.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(CLColor.inkSecondary)
                .accessibilityLabel("Error: \(message)")
            Button("Retry") {
                Task { await viewModel.loadProfile() }
            }
            .buttonStyle(CLSecondaryButtonStyle())
            .padding(.top, CLSpacing.xs)
            .accessibilityLabel("Retry loading profile")
        }
        .padding(CLSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
