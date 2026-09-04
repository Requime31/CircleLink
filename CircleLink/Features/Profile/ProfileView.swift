import SwiftUI

struct ProfileView: View {
    /// Flip to `true` to bring back the public-preview card without restoring from git.
    private static let showsHowOthersSeeYouPreview = false

    @ObservedObject var viewModel: ProfileViewModel
    let makeSettingsViewModel: () -> SettingsViewModel
    let makeSupportViewModel: () -> SupportViewModel
    let onSignOut: () -> Void
    let makeAccountDeletionViewModel: () -> AccountDeletionViewModel
    let makeBlockedPeopleViewModel: () -> BlockedPeopleViewModel

    @State private var isEditing = false
    @State private var composeMode: ComposeProfilePostSheet.Mode?
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                switch viewModel.state {
                case .idle, .loading:
                    CLLoadingState(message: "Loading profile…")
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
                SettingsView(
                    viewModel: makeSettingsViewModel(),
                    makeSupportViewModel: makeSupportViewModel,
                    makeBlockedPeopleViewModel: makeBlockedPeopleViewModel,
                    makeAccountDeletionViewModel: makeAccountDeletionViewModel
                )
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
                .padding(.horizontal, CLSpacing.screenHorizontal)
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
        CLProfileIdentity(
            name: displayName(for: user),
            detail: memberSubtitle(for: user),
            avatarURL: user.avatarURL,
            avatarBase64: user.avatarBase64,
            avatarSize: 112
        )
        .frame(maxWidth: .infinity)
        .padding(.horizontal, CLSpacing.screenHorizontal)
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
        CLCard(variant: .outlined) {
            CLProfileStatsRow(stats: [
                .init(id: "circles", value: ProfileViewModel.formattedCount(viewModel.circlesCount), label: "Circles"),
                .init(id: "connects", value: ProfileViewModel.formattedCount(viewModel.connectsCount), label: "Connects"),
                .init(id: "posts", value: ProfileViewModel.formattedCount(viewModel.postsCount), label: "Posts")
            ])
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(viewModel.circlesCount) circles, \(viewModel.connectsCount) connects, \(viewModel.postsCount) posts"
        )
    }

    private func myInterestsSection(user: User) -> some View {
        VStack(alignment: .leading, spacing: CLSpacing.md) {
            CLSectionHeader("My Interests")
            publicInterests(user.interests)
        }
    }

    private func myPostsSection(user: User) -> some View {
        VStack(alignment: .leading, spacing: CLSpacing.md) {
            CLSectionHeader("My Posts") {
                CLIconButton(systemImage: "plus", accessibilityLabel: "Create new post") {
                    viewModel.clearPostError()
                    composeMode = .create
                }
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
                    currentUserId: user.id,
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
            CLFlowLayout(horizontalSpacing: CLSpacing.xs, verticalSpacing: CLSpacing.xs) {
                ForEach(interests, id: \.self) { interest in
                    CLChip(title: interest)
                }
            }
        }
    }

    private var accountSection: some View {
        VStack(spacing: CLSpacing.sm) {
            CLSectionHeader("Account")

            Button {
                path.append(SettingsRoute())
            } label: {
                CLSettingsRow(title: "Settings", systemImage: "gearshape")
            }
            .buttonStyle(.plain)
            .background(CLColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: CLRadius.lg, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: CLRadius.lg, style: .continuous).stroke(CLColor.hairline))
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
        CLErrorState(title: "Couldn’t Load Profile", message: message, retryTitle: "Retry") {
            Task { await viewModel.loadProfile() }
        }
    }
}
