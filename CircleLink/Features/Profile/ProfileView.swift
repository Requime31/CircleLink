import SwiftUI

struct ProfileView: View {
    @ObservedObject var viewModel: ProfileViewModel
    let pushHandler: PushNotificationHandler
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
                SettingsView(pushHandler: pushHandler)
            }
            .task {
                await viewModel.loadProfile()
            }
        }
    }

    // MARK: - Loaded layout

    @ViewBuilder
    private func profileContent(user: User) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                profileHero(user: user)

                VStack(spacing: CLSpacing.xl) {
                    howOthersSeeYouCard(user: user)

                    accountSection
                }
                .padding(.horizontal, CLSpacing.md)
                .padding(.top, CLSpacing.lg)
                .padding(.bottom, CLSpacing.xxl)
            }
            .clAppear()
        }
    }

    /// Personal cabinet identity: soft atmosphere + avatar + name.
    private func profileHero(user: User) -> some View {
        VStack(spacing: CLSpacing.md) {
            AvatarImageView(
                localPreview: viewModel.localAvatarPreview,
                avatarBase64: user.avatarBase64,
                avatarURL: user.avatarURL,
                size: 112
            )
            .accessibilityLabel("Profile photo")
            .overlay(
                Circle()
                    .stroke(CLColor.surface.opacity(0.9), lineWidth: 3)
            )

            VStack(spacing: CLSpacing.xxs) {
                Text(displayName(for: user))
                    .font(CLTypography.title)
                    .foregroundStyle(CLColor.ink)
                    .multilineTextAlignment(.center)
                    .accessibilityLabel("Display name: \(displayName(for: user))")

                Text("Your profile")
                    .font(CLTypography.subheadline)
                    .foregroundStyle(CLColor.inkMuted)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, CLSpacing.lg)
        .padding(.top, CLSpacing.xl)
        .padding(.bottom, CLSpacing.xl)
        .background {
            LinearGradient(
                colors: [
                    CLColor.tintCream,
                    CLColor.primarySoft.opacity(0.55),
                    CLColor.canvas
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
        }
    }

    /// Read-only mirror of public fields — same visual language as peer profile.
    private func howOthersSeeYouCard(user: User) -> some View {
        VStack(alignment: .leading, spacing: CLSpacing.md) {
            VStack(alignment: .leading, spacing: CLSpacing.xxs) {
                Text("How others see you")
                    .font(CLTypography.headline)
                    .foregroundStyle(CLColor.ink)

                Text("This is what people see when they open your card.")
                    .font(CLTypography.footnote)
                    .foregroundStyle(CLColor.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(alignment: .top, spacing: CLSpacing.md) {
                AvatarImageView(
                    localPreview: viewModel.localAvatarPreview,
                    avatarBase64: user.avatarBase64,
                    avatarURL: user.avatarURL,
                    size: 64
                )
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: CLSpacing.xs) {
                    Text(displayName(for: user))
                        .font(CLTypography.title2)
                        .foregroundStyle(CLColor.ink)
                        .accessibilityHidden(true)

                    publicInterests(user.interests)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clCardStyle()
        .overlay(
            RoundedRectangle(cornerRadius: CLRadius.lg, style: .continuous)
                .stroke(CLColor.hairline, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(howOthersAccessibilityLabel(user: user))
    }

    @ViewBuilder
    private func publicInterests(_ interests: [String]) -> some View {
        if interests.isEmpty {
            Text("No interests yet")
                .font(CLTypography.subheadline)
                .foregroundStyle(CLColor.inkMuted)
        } else {
            FlowLayout(spacing: CLSpacing.xs) {
                ForEach(interests, id: \.self) { interest in
                    Text(interest)
                        .font(CLTypography.caption)
                        .foregroundStyle(CLColor.inkSecondary)
                        .padding(.horizontal, CLSpacing.sm)
                        .padding(.vertical, CLSpacing.xxs)
                        .background(CLColor.surfaceSoft)
                        .clipShape(Capsule())
                }
            }
        }
    }

    private var accountSection: some View {
        VStack(spacing: CLSpacing.sm) {
            Text("Account")
                .font(CLTypography.caption)
                .foregroundStyle(CLColor.inkMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, CLSpacing.xxs)
                .accessibilityAddTraits(.isHeader)

            Button {
                path.append(SettingsRoute())
            } label: {
                HStack(spacing: CLSpacing.sm) {
                    Image(systemName: "gearshape")
                        .font(.body.weight(.medium))
                        .foregroundStyle(CLColor.primaryPressed)
                        .frame(width: 28, alignment: .center)
                        .accessibilityHidden(true)

                    Text("Settings")
                        .font(CLTypography.body)
                        .foregroundStyle(CLColor.ink)

                    Spacer(minLength: CLSpacing.xs)

                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(CLColor.inkDisabled)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, CLSpacing.md)
                .padding(.vertical, CLSpacing.sm)
                .frame(maxWidth: .infinity, minHeight: AccessibilityHelpers.minimumTouchTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(CLColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: CLRadius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CLRadius.lg, style: .continuous)
                    .stroke(CLColor.hairline, lineWidth: 1)
            )
            .accessibilityLabel("Settings")
            .accessibilityHint("Opens notifications and about")

            LogoutButton(action: onSignOut)
                .frame(maxWidth: .infinity)
                .padding(.vertical, CLSpacing.sm)
                .background(CLColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: CLRadius.lg, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: CLRadius.lg, style: .continuous)
                        .stroke(CLColor.hairline, lineWidth: 1)
                )
        }
        .padding(.top, CLSpacing.xl)
    }

    private func howOthersAccessibilityLabel(user: User) -> String {
        let interests = user.interests.isEmpty
            ? "No interests yet"
            : "Interests: \(user.interests.joined(separator: ", "))"
        // Name is already announced in the hero — avoid VoiceOver duplication.
        return "How others see you. \(interests)"
    }

    private func displayName(for user: User) -> String {
        user.displayName.isEmpty ? "Member" : user.displayName
    }

    // MARK: - Empty / error

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
