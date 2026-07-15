import SwiftUI

struct ProfileView: View {
    @ObservedObject var viewModel: ProfileViewModel
    let onSignOut: () -> Void
    let onOpenDebugChat: () -> Void

    @State private var isEditing = false

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .idle, .loading:
                    ProgressView("Loading profile…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .empty:
                    emptyState
                case let .error(message):
                    errorState(message: message)
                case let .loaded(user):
                    profileContent(user: user)
                }
            }
            .navigationTitle("Profile")
            .toolbar {
                if case .loaded = viewModel.state {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Edit") {
                            isEditing = true
                        }
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
            VStack(spacing: 24) {
                AvatarImageView(
                    localPreview: viewModel.localAvatarPreview,
                    avatarBase64: user.avatarBase64,
                    avatarURL: user.avatarURL,
                    size: 120
                )
                .accessibilityLabel("Profile photo")

                VStack(spacing: 4) {
                    Text(user.displayName)
                        .font(.title2.bold())
                        .accessibilityLabel("Display name: \(user.displayName)")

                    if user.interests.isEmpty {
                        Text("No interests yet")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if !user.interests.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Interests")
                            .font(.headline)

                        FlowLayout(spacing: 8) {
                            ForEach(user.interests, id: \.self) { interest in
                                Text(interest)
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.secondary.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                LogoutButton(action: onSignOut)
                    .padding(.top, 16)

                Button("Open Debug Chat") {
                    onOpenDebugChat()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 1.0, green: 0.22, blue: 0.36))
                .accessibilityLabel("Open debug chat")
            }
            .padding(24)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("Profile not found")
                .font(.title3)
            Button("Retry") {
                Task { await viewModel.loadProfile() }
            }
            .accessibilityLabel("Retry loading profile")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Error: \(message)")
            Button("Retry") {
                Task { await viewModel.loadProfile() }
            }
            .accessibilityLabel("Retry loading profile")
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
