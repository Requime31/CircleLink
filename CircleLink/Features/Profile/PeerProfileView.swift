import SwiftUI

/// Shared peer profile content — hero, about, interests, communities + mode-specific actions.
/// Present via `PeerProfileSheet`. Not the owner's edit Profile.
struct PeerProfileView: View {
    @ObservedObject var viewModel: PeerProfileViewModel
    var onClose: (() -> Void)?
    var onOpenChat: ((String, String) -> Void)?

    @State private var showRemoveConfirmation = false

    var body: some View {
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
        .overlay(alignment: .topLeading) {
            if onClose != nil {
                closeButton
            }
        }
        .overlay(alignment: .topTrailing) {
            if viewModel.mode == .social, viewModel.relationship == .matched {
                Menu {
                    Button("Remove connection", role: .destructive) {
                        showRemoveConfirmation = true
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(CLColor.ink)
                        .frame(width: 44, height: 44)
                        .background(CLColor.surface.opacity(0.92))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(CLColor.hairline, lineWidth: 1))
                }
                .padding(.trailing, CLSpacing.screenHorizontal)
                .padding(.top, CLSpacing.sm)
                .accessibilityLabel("Profile actions")
            }
        }
        .safeAreaInset(edge: .bottom) {
            if case .loaded = viewModel.state {
                actionBar
            }
        }
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

    private func profileContent(user: User) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CLSpacing.lg) {
                heroCard(user: user)

                if !user.interests.isEmpty {
                    interestsSection(user.interests)
                }

                aboutSection(user.aboutMe)

                if !viewModel.communities.isEmpty {
                    communitiesSection
                }

                feedSection(user: user)

                if let message = viewModel.actionErrorMessage {
                    Text(message)
                        .font(CLTypography.footnote)
                        .foregroundStyle(CLColor.error)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityLabel("Error: \(message)")
                }
            }
            .padding(.horizontal, CLSpacing.screenHorizontal)
            .padding(.top, CLSpacing.xl)
            .padding(.bottom, CLSpacing.xxl)
        }
    }

    private func heroCard(user: User) -> some View {
        Color.clear
            .aspectRatio(4 / 5, contentMode: .fit)
            .overlay {
                ProfileHeroImageView(
                    avatarBase64: user.avatarBase64,
                    avatarURL: user.avatarURL
                )
            }
            .overlay {
                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.55)],
                    startPoint: .center,
                    endPoint: .bottom
                )
            }
            .overlay(alignment: .bottomLeading) {
                Text(user.displayNameWithAge)
                    .font(CLTypography.largeTitle)
                    .foregroundStyle(.white)
                    .padding(CLSpacing.lg)
            }
            .clipShape(RoundedRectangle(cornerRadius: CLRadius.xl, style: .continuous))
            .shadow(color: CLShadow.cardColor, radius: CLShadow.cardRadius, x: 0, y: CLShadow.cardY)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(user.displayNameWithAge)
    }

    private func interestsSection(_ interests: [String]) -> some View {
        VStack(alignment: .leading, spacing: CLSpacing.sm) {
            Text("Interests")
                .font(CLTypography.title)
                .foregroundStyle(CLColor.ink)

            FlowLayout(spacing: CLSpacing.sm) {
                ForEach(interests, id: \.self) { interest in
                    CLChip(title: interest)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func aboutSection(_ aboutMe: String) -> some View {
        VStack(alignment: .leading, spacing: CLSpacing.sm) {
            Text("About")
                .font(CLTypography.caption)
                .foregroundStyle(CLColor.inkMuted)
                .textCase(.uppercase)

            Text(aboutMe.isEmpty ? "No bio yet." : aboutMe)
                .font(CLTypography.callout)
                .foregroundStyle(aboutMe.isEmpty ? CLColor.inkMuted : CLColor.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(CLSpacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(CLColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: CLRadius.lg, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: CLRadius.lg, style: .continuous)
                        .stroke(CLColor.hairline, lineWidth: 1)
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var communitiesSection: some View {
        VStack(alignment: .leading, spacing: CLSpacing.sm) {
            Text("Communities")
                .font(CLTypography.title)
                .foregroundStyle(CLColor.ink)

            FlowLayout(spacing: CLSpacing.sm) {
                ForEach(viewModel.visibleCommunities) { community in
                    CLChip(title: community.name)
                }

                if viewModel.overflowCommunityCount > 0 {
                    CLChip(
                        title: "+\(viewModel.overflowCommunityCount)",
                        isEmphasized: true,
                        accessibilityLabelText: "\(viewModel.overflowCommunityCount) more communities"
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func feedSection(user: User) -> some View {
        VStack(alignment: .leading, spacing: CLSpacing.sm) {
            Text("Feed")
                .font(CLTypography.title)
                .foregroundStyle(CLColor.ink)
                .accessibilityAddTraits(.isHeader)

            if viewModel.posts.isEmpty {
                Text("No posts yet.")
                    .font(CLTypography.subheadline)
                    .foregroundStyle(CLColor.inkMuted)
                    .padding(.vertical, CLSpacing.sm)
            } else {
                ProfilePostsListView(
                    posts: viewModel.posts,
                    author: user,
                    localAvatarPreview: nil
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Actions

    @ViewBuilder
    private var actionBar: some View {
        switch viewModel.mode {
        case .likedYou:
            connectActionBar
        case .social:
            socialActionBar
        }
    }

    private var connectActionBar: some View {
        HStack(spacing: CLSpacing.lg) {
            circularAction(
                systemImage: "xmark",
                label: skipAccessibilityLabel,
                isEmphasis: false,
                size: 64
            ) {
                Task { await viewModel.skip() }
            }

            circularAction(
                systemImage: "heart.fill",
                label: likeAccessibilityLabel,
                isEmphasis: true,
                size: 72
            ) {
                Task { await viewModel.like() }
            }
        }
        .padding(.vertical, CLSpacing.md)
        .frame(maxWidth: .infinity)
        .background(CLColor.canvas.opacity(0.92))
        .disabled(viewModel.isActing)
    }

    private var socialActionBar: some View {
        VStack(spacing: CLSpacing.sm) {
            switch viewModel.relationship {
            case .none:
                if viewModel.canConnect {
                    Button {
                        Task { await viewModel.connect() }
                    } label: {
                        if viewModel.isActing {
                            ProgressView()
                                .tint(CLColor.onPrimaryStrong)
                        } else {
                            Text("Connect")
                        }
                    }
                    .buttonStyle(CLPrimaryButtonStyle())
                    .disabled(viewModel.isActing)
                    .accessibilityLabel("Connect")
                }

            case .pending:
                Button("Request sent") {}
                    .buttonStyle(CLPrimaryButtonStyle())
                    .disabled(true)
                    .accessibilityLabel("Request sent")

            case .matched:
                Button {
                    Task {
                        if let result = await viewModel.openChat() {
                            onOpenChat?(result.chatId, result.title)
                        }
                    }
                } label: {
                    if viewModel.isOpeningChat {
                        ProgressView().tint(CLColor.ink)
                    } else {
                        Label("Message", systemImage: "message")
                    }
                }
                .buttonStyle(CLPrimaryButtonStyle())
                .disabled(viewModel.isOpeningChat)
                .accessibilityLabel("Message")
            }
        }
        .padding(.horizontal, CLSpacing.screenHorizontal)
        .padding(.vertical, CLSpacing.md)
        .frame(maxWidth: .infinity)
        .background(CLColor.canvas.opacity(0.92))
    }

    private var likeAccessibilityLabel: String {
        switch viewModel.mode {
        case .likedYou: return "Like"
        case .social: return "Like"
        }
    }

    private var skipAccessibilityLabel: String {
        switch viewModel.mode {
        case .likedYou: return "Skip"
        case .social: return "Skip"
        }
    }

    private func circularAction(
        systemImage: String,
        label: String,
        isEmphasis: Bool,
        size: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack {
                if viewModel.isActing && isEmphasis {
                    ProgressView()
                        .tint(isEmphasis ? CLColor.onPrimaryStrong : CLColor.ink)
                } else {
                    Image(systemName: systemImage)
                        .font(.system(size: size * 0.32, weight: .semibold))
                        .foregroundStyle(isEmphasis ? CLColor.onPrimaryStrong : CLColor.inkSecondary)
                }
            }
            .frame(width: size, height: size)
            .background(isEmphasis ? CLColor.primary : CLColor.surface)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(CLColor.hairline, lineWidth: isEmphasis ? 0 : 1)
            )
            .shadow(color: CLShadow.cardColor, radius: CLShadow.cardRadius, x: 0, y: CLShadow.cardY)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var closeButton: some View {
        Button {
            onClose?()
        } label: {
            Image(systemName: "chevron.down")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(CLColor.ink)
                .frame(width: 44, height: 44)
                .background(CLColor.surface.opacity(0.92))
                .clipShape(Circle())
                .overlay(Circle().stroke(CLColor.hairline, lineWidth: 1))
        }
        .padding(.leading, CLSpacing.screenHorizontal)
        .padding(.top, CLSpacing.sm)
        .accessibilityLabel("Close profile")
    }

    // MARK: - Empty / error

    private var emptyState: some View {
        CLEmptyState(
            systemImage: "person.crop.circle.badge.exclamationmark",
            title: "Profile not found",
            actionTitle: onClose != nil ? "Close" : "Retry",
            actionAccessibilityLabel: onClose != nil ? "Close profile" : "Retry loading profile",
            action: onClose ?? { Task { await viewModel.load() } }
        )
    }

    private func errorState(message: String) -> some View {
        CLEmptyState(
            systemImage: "exclamationmark.triangle",
            title: message,
            actionTitle: "Retry",
            actionAccessibilityLabel: "Retry loading profile",
            titleAccessibilityLabel: "Error: \(message)"
        ) {
            Task { await viewModel.load() }
        }
    }
}
