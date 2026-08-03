import SwiftUI

/// Public-facing peer profile content (avatar → name → interests → CTA).
/// Present via `PeerProfileSheet`. Not the owner's edit Profile.
struct PeerProfileView: View {
    @ObservedObject var viewModel: PeerProfileViewModel

    @State private var showRemoveConfirmation = false

    var body: some View {
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
        .alert(
            "Remove connection?",
            isPresented: $showRemoveConfirmation
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                Task { await viewModel.removeConnection() }
            }
        } message: {
            Text("You’ll no longer be connected. Chat history stays.")
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func profileContent(user: User) -> some View {
        ScrollView {
            VStack(spacing: CLSpacing.lg) {
                AvatarImageView(
                    localPreview: nil,
                    avatarBase64: user.avatarBase64,
                    avatarURL: user.avatarURL,
                    size: 120
                )
                .accessibilityLabel("Profile photo")

                Text(user.displayName.isEmpty ? "Member" : user.displayName)
                    .font(CLTypography.title)
                    .foregroundStyle(CLColor.ink)
                    .multilineTextAlignment(.center)
                    .accessibilityLabel("Display name: \(user.displayName)")

                interestsSection(user.interests)

                actionSection

                if let message = viewModel.actionErrorMessage {
                    Text(message)
                        .font(CLTypography.footnote)
                        .foregroundStyle(CLColor.error)
                        .multilineTextAlignment(.center)
                        .accessibilityLabel("Error: \(message)")
                }
            }
            .padding(.horizontal, CLSpacing.lg)
            .padding(.top, CLSpacing.xl)
            .padding(.bottom, CLSpacing.xxl)
            .frame(maxWidth: .infinity)
            .clAppear()
        }
    }

    @ViewBuilder
    private func interestsSection(_ interests: [String]) -> some View {
        if interests.isEmpty {
            Text("No interests yet")
                .font(CLTypography.subheadline)
                .foregroundStyle(CLColor.inkMuted)
        } else {
            VStack(alignment: .leading, spacing: CLSpacing.xs) {
                Text("Interests")
                    .font(CLTypography.headline)
                    .foregroundStyle(CLColor.ink)

                FlowLayout(spacing: CLSpacing.xs) {
                    ForEach(interests, id: \.self) { interest in
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
    }

    @ViewBuilder
    private var actionSection: some View {
        VStack(spacing: CLSpacing.sm) {
            switch viewModel.relationship {
            case .none:
                if viewModel.canConnect {
                    Button {
                        Task { await viewModel.connect() }
                    } label: {
                        if viewModel.isActing {
                            ProgressView()
                                .tint(CLColor.onPrimary)
                        } else {
                            Text("Connect")
                        }
                    }
                    .buttonStyle(CLPrimaryButtonStyle())
                    .disabled(viewModel.isActing)
                    .accessibilityLabel("Connect")
                } else if viewModel.showsConnectUnavailableHint {
                    Text("Connect from a community")
                        .font(CLTypography.subheadline)
                        .foregroundStyle(CLColor.inkMuted)
                        .multilineTextAlignment(.center)
                }

            case .pending:
                Button("Request sent") {}
                    .buttonStyle(CLPrimaryButtonStyle())
                    .disabled(true)
                    .accessibilityLabel("Request sent")

            case .matched:
                Button {
                    showRemoveConfirmation = true
                } label: {
                    if viewModel.isActing {
                        ProgressView()
                            .tint(CLColor.ink)
                    } else {
                        Text("Remove from connections")
                    }
                }
                .buttonStyle(CLSecondaryButtonStyle())
                .disabled(viewModel.isActing)
                .accessibilityLabel("Remove from connections")
            }
        }
        .padding(.top, CLSpacing.sm)
    }

    // MARK: - Empty / error

    private var emptyState: some View {
        CLEmptyState(
            systemImage: "person.crop.circle.badge.exclamationmark",
            title: "Profile not found",
            actionTitle: "Retry",
            actionAccessibilityLabel: "Retry loading profile"
        ) {
            Task { await viewModel.load() }
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
            Task { await viewModel.load() }
        }
    }
}
