import SwiftUI

struct ProfileView: View {
    /// Flip to `true` to bring back the public-preview card without restoring from git.
    private static let showsHowOthersSeeYouPreview = false

    @ObservedObject var viewModel: ProfileViewModel
    let pushHandler: PushNotificationHandler
    let onSignOut: () -> Void

    @State private var isEditing = false
    @State private var composeMode: ComposeProfilePostSheet.Mode?
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
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(isPresented: $isEditing) {
                ProfileEditView(viewModel: viewModel)
            }
            .navigationDestination(for: SettingsRoute.self) { _ in
                SettingsView(pushHandler: pushHandler)
            }
            .sheet(item: $composeMode) { mode in
                ComposeProfilePostSheet(viewModel: viewModel, mode: mode) {
                    composeMode = nil
                }
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
                    actionButtons

                    statsRow

                    if Self.showsHowOthersSeeYouPreview {
                        howOthersSeeYouCard(user: user)
                    }

                    myInterestsSection(user: user)

                    myPostsSection(user: user)

                    accountSection
                }
                .padding(.horizontal, CLSpacing.md)
                .padding(.top, CLSpacing.lg)
                .padding(.bottom, CLSpacing.xxl)
            }
            .clAppear()
        }
        .alert(
            "Couldn’t delete post",
            isPresented: Binding(
                get: { viewModel.postErrorMessage != nil },
                set: { if !$0 { viewModel.clearPostError() } }
            )
        ) {
            Button("OK", role: .cancel) {
                viewModel.clearPostError()
            }
        } message: {
            Text(viewModel.postErrorMessage ?? "")
        }
    }

    /// Avatar + name + member subtitle (design: my_profile).
    private func profileHero(user: User) -> some View {
        VStack(spacing: CLSpacing.md) {
            AvatarImageView(
                localPreview: viewModel.localAvatarPreview,
                avatarBase64: user.avatarBase64,
                avatarURL: user.avatarURL,
                size: 112
            )
            .accessibilityLabel("Profile photo")
            .overlay(alignment: .bottomTrailing) {
                Circle()
                    .fill(CLColor.primary)
                    .frame(width: 22, height: 22)
                    .overlay(
                        Circle()
                            .stroke(CLColor.surface, lineWidth: 3)
                    )
                    .offset(x: -4, y: -4)
                    .accessibilityHidden(true)
            }

            VStack(spacing: CLSpacing.xxs) {
                Text(displayName(for: user))
                    .font(CLTypography.title)
                    .foregroundStyle(CLColor.ink)
                    .multilineTextAlignment(.center)
                    .accessibilityLabel("Display name: \(displayName(for: user))")

                Text(memberSubtitle(for: user))
                    .font(CLTypography.subheadline)
                    .foregroundStyle(CLColor.inkMuted)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, CLSpacing.lg)
        .padding(.top, CLSpacing.xl)
        .padding(.bottom, CLSpacing.md)
    }

    private var actionButtons: some View {
        HStack(spacing: CLSpacing.sm) {
            Button {
                isEditing = true
            } label: {
                Label("Edit Profile", systemImage: "pencil")
            }
            .buttonStyle(CLPrimaryButtonStyle())
            .accessibilityLabel("Edit profile")

            ShareLink(item: shareText) {
                Text("Share")
                    .font(CLTypography.button)
                    .foregroundStyle(CLColor.ink)
                    .frame(minWidth: 88)
                    .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
                    .padding(.horizontal, CLSpacing.md)
                    .background(CLColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous)
                            .stroke(CLColor.hairline, lineWidth: 1)
                    )
            }
            .accessibilityLabel("Share profile")
        }
    }

    private var statsRow: some View {
        HStack(spacing: 0) {
            statCell(
                value: ProfileViewModel.formattedCount(viewModel.circlesCount),
                label: "Circles"
            )
            Divider()
                .frame(height: 36)
                .overlay(CLColor.hairline)
            statCell(
                value: ProfileViewModel.formattedCount(viewModel.connectsCount),
                label: "Connects"
            )
            Divider()
                .frame(height: 36)
                .overlay(CLColor.hairline)
            statCell(
                value: ProfileViewModel.formattedCount(viewModel.postsCount),
                label: "Posts"
            )
        }
        .padding(.vertical, CLSpacing.md)
        .frame(maxWidth: .infinity)
        .background(CLColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: CLRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CLRadius.lg, style: .continuous)
                .stroke(CLColor.hairline, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(viewModel.circlesCount) circles, \(viewModel.connectsCount) connects, \(viewModel.postsCount) posts"
        )
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: CLSpacing.xxs) {
            Text(value)
                .font(CLTypography.title2)
                .foregroundStyle(CLColor.primaryPressed)
            Text(label.uppercased())
                .font(CLTypography.caption)
                .foregroundStyle(CLColor.inkMuted)
                .tracking(0.6)
        }
        .frame(maxWidth: .infinity)
    }

    private func myInterestsSection(user: User) -> some View {
        VStack(alignment: .leading, spacing: CLSpacing.md) {
            HStack {
                Text("My Interests")
                    .font(CLTypography.headline)
                    .foregroundStyle(CLColor.ink)
                    .accessibilityAddTraits(.isHeader)

                Spacer(minLength: CLSpacing.xs)

                Button("Edit") {
                    isEditing = true
                }
                .font(CLTypography.subheadline.weight(.semibold))
                .foregroundStyle(CLColor.primaryPressed)
                .accessibilityLabel("Edit interests")
            }

            publicInterests(user.interests)
        }
    }

    private func myPostsSection(user: User) -> some View {
        VStack(alignment: .leading, spacing: CLSpacing.md) {
            HStack {
                Text("My Posts")
                    .font(CLTypography.headline)
                    .foregroundStyle(CLColor.ink)
                    .accessibilityAddTraits(.isHeader)

                Spacer(minLength: CLSpacing.xs)

                Button {
                    viewModel.clearPostError()
                    composeMode = .create
                } label: {
                    Image(systemName: "plus")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(CLColor.primaryPressed)
                        .frame(minWidth: AccessibilityHelpers.minimumTouchTarget,
                               minHeight: AccessibilityHelpers.minimumTouchTarget)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Create new post")
            }

            if viewModel.posts.isEmpty {
                Text("No posts yet. Share a photo or a thought.")
                    .font(CLTypography.subheadline)
                    .foregroundStyle(CLColor.inkMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(CLSpacing.md)
                    .background(CLColor.surfaceSoft)
                    .clipShape(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous))
            } else {
                ProfilePostsListView(
                    posts: viewModel.posts,
                    author: user,
                    localAvatarPreview: viewModel.localAvatarPreview,
                    onDelete: { post in
                        Task { await viewModel.deletePost(post) }
                    },
                    onEdit: { post in
                        viewModel.clearPostError()
                        composeMode = .edit(post)
                    }
                )
            }
        }
    }

    // MARK: - How others see you (kept, not shown)

    /// Read-only mirror of public fields — same visual language as peer profile.
    /// Temporarily not rendered from `profileContent` (product pause).
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
                        .clipShape(RoundedRectangle(cornerRadius: CLRadius.sm, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: CLRadius.sm, style: .continuous)
                                .stroke(CLColor.hairline, lineWidth: 1)
                        )
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

    // MARK: - Helpers

    private var shareText: String {
        let name = viewModel.profile.map(displayName(for:)) ?? "Member"
        return "Check out \(name) on CircleLink"
    }

    private func memberSubtitle(for user: User) -> String {
        if let date = user.ageConfirmedAt {
            return "Member since \(date.formatted(.dateTime.month(.wide).year()))"
        }
        return "Your profile"
    }

    private func howOthersAccessibilityLabel(user: User) -> String {
        let interests = user.interests.isEmpty
            ? "No interests yet"
            : "Interests: \(user.interests.joined(separator: ", "))"
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
