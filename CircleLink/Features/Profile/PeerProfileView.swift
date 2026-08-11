import SwiftUI

/// Shared peer profile content — hero, about, interests, communities + mode-specific actions.
/// Present via `PeerProfileSheet`. Not the owner's edit Profile.
struct PeerProfileView: View {
    @ObservedObject var viewModel: PeerProfileViewModel
    var onClose: (() -> Void)?

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
        .overlay(alignment: .topLeading) {
            if onClose != nil {
                closeButton
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
                    Text(interest)
                        .font(CLTypography.footnote)
                        .foregroundStyle(CLColor.inkSecondary)
                        .padding(.horizontal, CLSpacing.md)
                        .padding(.vertical, CLSpacing.xs)
                        .background(CLColor.surfaceSoft)
                        .clipShape(Capsule(style: .continuous))
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
                    Text(community.name)
                        .font(CLTypography.footnote)
                        .foregroundStyle(CLColor.inkSecondary)
                        .padding(.horizontal, CLSpacing.md)
                        .padding(.vertical, CLSpacing.xs)
                        .background(CLColor.surfaceSoft)
                        .clipShape(Capsule(style: .continuous))
                }

                if viewModel.overflowCommunityCount > 0 {
                    Text("+\(viewModel.overflowCommunityCount)")
                        .font(CLTypography.footnote.weight(.semibold))
                        .foregroundStyle(CLColor.primaryPressed)
                        .padding(.horizontal, CLSpacing.md)
                        .padding(.vertical, CLSpacing.xs)
                        .background(CLColor.primarySoft)
                        .clipShape(Capsule(style: .continuous))
                        .accessibilityLabel("\(viewModel.overflowCommunityCount) more communities")
                }
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
        VStack(spacing: CLSpacing.sm) {
            Text("Profile not found")
                .font(CLTypography.title2)
                .foregroundStyle(CLColor.ink)
            if let onClose {
                Button("Close", action: onClose)
                    .buttonStyle(CLSecondaryButtonStyle())
            } else {
                Button("Retry") {
                    Task { await viewModel.load() }
                }
                .buttonStyle(CLSecondaryButtonStyle())
            }
        }
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: CLSpacing.sm) {
            Text(message)
                .font(CLTypography.body)
                .foregroundStyle(CLColor.inkSecondary)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task { await viewModel.load() }
            }
            .buttonStyle(CLSecondaryButtonStyle())
        }
        .padding(CLSpacing.lg)
    }
}
