import SwiftUI

/// Profile screen in Soft Orbit language. ViewModel bindings unchanged.
///
/// Data flow:
/// Appear → ProfileViewModel.loadProfile → UserRepository → state → UI
/// Edit → ProfileEditView → saveProfile → dismiss
/// Log out → onSignOut
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
                        .foregroundStyle(CLColor.muted)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .empty:
                    emptyState
                case let .error(message):
                    errorState(message: message)
                case let .loaded(user):
                    profileContent(user: user)
                }
            }
            .background(CLColor.canvas.ignoresSafeArea())
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
                VStack(spacing: CLSpacing.md) {
                    AvatarImageView(
                        localPreview: viewModel.localAvatarPreview,
                        avatarBase64: user.avatarBase64,
                        avatarURL: user.avatarURL,
                        size: 120
                    )
                    .accessibilityLabel("Profile photo")

                    VStack(spacing: CLSpacing.xs) {
                        Text(user.displayName)
                            .font(CLTypography.title)
                            .foregroundStyle(CLColor.ink)
                            .accessibilityLabel("Display name: \(user.displayName)")

                        if user.interests.isEmpty {
                            Text("No interests yet")
                                .font(CLTypography.callout)
                                .foregroundStyle(CLColor.muted)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(CLSpacing.lg)
                .clCardStyle()
                .clAppear()

                if !user.interests.isEmpty {
                    VStack(alignment: .leading, spacing: CLSpacing.md) {
                        Text("Interests")
                            .font(CLTypography.section)
                            .foregroundStyle(CLColor.ink)

                        FlowLayout(spacing: CLSpacing.sm) {
                            ForEach(user.interests, id: \.self) { interest in
                                CLMetaPill(title: interest)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(CLSpacing.base)
                    .clCardStyle()
                    .clAppear(delay: 0.05)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Interests: \(user.interests.joined(separator: ", "))")
                }

                LogoutButton(action: onSignOut)
                    .padding(.top, CLSpacing.sm)
                    .clAppear(delay: 0.08)
            }
            .padding(CLSpacing.base)
        }
    }

    private var emptyState: some View {
        CLEmptyState(
            systemImage: "person.crop.circle.badge.exclamationmark",
            title: "Profile not found",
            message: "We couldn't find your profile. Try again in a moment.",
            actionTitle: "Retry",
            actionAccessibilityLabel: "Retry loading profile"
        ) {
            Task { await viewModel.loadProfile() }
        }
    }

    private func errorState(message: String) -> some View {
        CLEmptyState(
            systemImage: "exclamationmark.triangle.fill",
            title: "Couldn't load profile",
            message: message,
            actionTitle: "Retry",
            actionAccessibilityLabel: "Retry loading profile",
            titleAccessibilityLabel: "Error: Couldn't load profile"
        ) {
            Task { await viewModel.loadProfile() }
        }
    }
}
