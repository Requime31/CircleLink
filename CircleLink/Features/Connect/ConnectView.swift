import SwiftUI

/// Connect tab root = Discover (community + swipe deck).
/// Liked you / Matches are push destinations. Connect action lives in PeerProfileSheet.
struct ConnectView: View {
    @ObservedObject var tab: ConnectTabModel
    let makePeerProfileSheet: (String, String?) -> PeerProfileSheet

    @State private var reportTarget: ModerationTarget?
    @State private var blockTarget: ModerationTarget?
    @State private var presentedPeer: PresentedPeer?

    private var discovery: ConnectDiscoveryViewModel { tab.discovery }

    var body: some View {
        NavigationStack {
            discoverContent
                .clCanvasBackground()
                .navigationTitle("Connect")
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        NavigationLink(value: ConnectDestination.likedYou) {
                            toolbarLabel(
                                title: "Liked you",
                                systemImage: "heart",
                                badge: tab.incomingCount
                            )
                        }
                        .accessibilityLabel(likedYouAccessibilityLabel)
                        .disabled(!tab.isBlockFilterReady)

                        NavigationLink(value: ConnectDestination.matches) {
                            toolbarLabel(
                                title: "Matches",
                                systemImage: "link",
                                badge: tab.matchedCount
                            )
                        }
                        .accessibilityLabel(matchesAccessibilityLabel)
                        .disabled(!tab.isBlockFilterReady)
                    }
                }
                .navigationDestination(for: ConnectDestination.self) { destination in
                    switch destination {
                    case .likedYou:
                        LikedYouView(
                            viewModel: tab.inbox,
                            onSelectPeer: { presentPeer($0) },
                            onReport: { userId, name in
                                reportTarget = ModerationTarget(userId: userId, displayName: name)
                            },
                            onBlock: { userId, name in
                                blockTarget = ModerationTarget(userId: userId, displayName: name)
                            }
                        )
                    case .matches:
                        MatchesView(
                            viewModel: tab.matches,
                            onSelectPeer: { presentPeer($0) },
                            onReport: { userId, name in
                                reportTarget = ModerationTarget(userId: userId, displayName: name)
                            },
                            onBlock: { userId, name in
                                blockTarget = ModerationTarget(userId: userId, displayName: name)
                            }
                        )
                    }
                }
                .task {
                    await tab.load()
                }
                .refreshable {
                    await tab.load()
                }
                .sheet(item: $presentedPeer) { peer in
                    makePeerProfileSheet(peer.userId, tab.selectedCommunityId)
                        .onDisappear {
                            Task { await tab.refreshAfterPeerSheet() }
                        }
                }
                .confirmationDialog(
                    "Why are you reporting this user?",
                    isPresented: Binding(
                        get: { reportTarget != nil },
                        set: { if !$0 { reportTarget = nil } }
                    ),
                    titleVisibility: .visible
                ) {
                    if let reportTarget {
                        ForEach(ReportReason.allCases, id: \.self) { reason in
                            Button(reason.title) {
                                Task {
                                    await tab.report(userId: reportTarget.userId, reason: reason)
                                }
                            }
                        }
                    }
                    Button("Cancel", role: .cancel) {
                        reportTarget = nil
                    }
                }
                .confirmationDialog(
                    blockConfirmTitle,
                    isPresented: Binding(
                        get: { blockTarget != nil },
                        set: { if !$0 { blockTarget = nil } }
                    ),
                    titleVisibility: .visible
                ) {
                    if let blockTarget {
                        Button("Block", role: .destructive) {
                            Task {
                                await tab.block(userId: blockTarget.userId)
                            }
                        }
                    }
                    Button("Cancel", role: .cancel) {
                        blockTarget = nil
                    }
                }
        }
    }

    // MARK: - Discover

    private var discoverContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CLSpacing.lg) {
                if let blockedUsersErrorMessage = tab.blockedUsersErrorMessage {
                    HStack(alignment: .top, spacing: CLSpacing.sm) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(CLColor.inkSecondary)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: CLSpacing.xxs) {
                            Text(blockFilterWarningTitle)
                                .font(CLTypography.footnote.weight(.semibold))
                                .foregroundStyle(CLColor.ink)
                            Text(blockedUsersErrorMessage)
                                .font(CLTypography.caption)
                                .foregroundStyle(CLColor.inkSecondary)
                                .lineLimit(2)
                            Button("Retry") {
                                Task { await tab.load() }
                            }
                            .font(CLTypography.footnote.weight(.medium))
                            .foregroundStyle(CLColor.primaryPressed)
                            .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
                        }
                    }
                    .padding(CLSpacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(CLColor.tintCream)
                    .clipShape(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous))
                }

                if let actionErrorMessage = tab.actionErrorMessage {
                    Text(actionErrorMessage)
                        .font(CLTypography.footnote)
                        .foregroundStyle(CLColor.error)
                        .padding(CLSpacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(CLColor.errorSoft)
                        .clipShape(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous))
                        .accessibilityLabel("Connect error: \(actionErrorMessage)")
                }

                if let moderationMessage = tab.moderationMessage {
                    Text(moderationMessage)
                        .font(CLTypography.footnote)
                        .foregroundStyle(CLColor.inkSecondary)
                        .padding(CLSpacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(CLColor.surfaceSoft)
                        .clipShape(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous))
                        .onTapGesture { tab.clearModerationFeedback() }
                }

                if !tab.isBlockFilterReady && tab.blockedUsersErrorMessage == nil {
                    HStack(spacing: CLSpacing.sm) {
                        ProgressView()
                            .tint(CLColor.primary)
                        Text("Checking blocked profiles…")
                            .font(CLTypography.subheadline)
                            .foregroundStyle(CLColor.inkSecondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 80)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Checking blocked profiles")
                }

                if tab.isBlockFilterReady {
                    communityPickerSection
                    deckSection
                }
            }
            .padding(.horizontal, CLSpacing.md)
            .padding(.vertical, CLSpacing.md)
        }
    }

    private func toolbarLabel(title: String, systemImage: String, badge: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(CLColor.ink)
                .frame(minWidth: 28, minHeight: AccessibilityHelpers.minimumTouchTarget)

            if badge > 0 {
                Text(badge > 99 ? "99+" : "\(badge)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(CLColor.onPrimary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(CLColor.primary)
                    .clipShape(Capsule())
                    .offset(x: 8, y: -4)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
    }

    private var likedYouAccessibilityLabel: String {
        let count = tab.incomingCount
        if count == 0 { return "Liked you" }
        return "Liked you, \(count) pending"
    }

    private var matchesAccessibilityLabel: String {
        let count = tab.matchedCount
        if count == 0 { return "Matches" }
        return "Matches, \(count)"
    }

    // MARK: - Community picker

    @ViewBuilder
    private var communityPickerSection: some View {
        VStack(alignment: .leading, spacing: CLSpacing.sm) {
            Text("Community")
                .font(CLTypography.headline)
                .foregroundStyle(CLColor.ink)

            switch discovery.communitiesState {
            case .idle, .loading:
                ProgressView("Loading communities…")
                    .tint(CLColor.primary)
                    .foregroundStyle(CLColor.inkMuted)
            case .empty:
                Text("Join a community first to find people.")
                    .font(CLTypography.subheadline)
                    .foregroundStyle(CLColor.inkMuted)
            case let .error(message):
                sectionError(message) {
                    Task { await tab.load() }
                }
            case let .loaded(communities):
                Menu {
                    ForEach(communities) { community in
                        Button(community.name) {
                            Task { await discovery.selectCommunity(community.id) }
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedCommunityName(from: communities))
                            .font(CLTypography.body.weight(.medium))
                            .foregroundStyle(CLColor.ink)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(CLColor.inkMuted)
                            .accessibilityHidden(true)
                    }
                    .padding(.horizontal, CLSpacing.md)
                    .frame(height: 48)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(CLColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous)
                            .stroke(CLColor.hairline, lineWidth: 1)
                    )
                }
                .accessibilityLabel("Select community")
            }
        }
    }

    // MARK: - Deck

    @ViewBuilder
    private var deckSection: some View {
        VStack(alignment: .leading, spacing: CLSpacing.sm) {
            Text("Discover")
                .font(CLTypography.headline)
                .foregroundStyle(CLColor.ink)

            if discovery.selectedCommunityId == nil {
                Text("Select a community to see people.")
                    .font(CLTypography.subheadline)
                    .foregroundStyle(CLColor.inkMuted)
            } else {
                switch discovery.candidatesState {
                case .idle, .loading:
                    ProgressView("Loading people…")
                        .tint(CLColor.primary)
                        .foregroundStyle(CLColor.inkMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, CLSpacing.xl)
                case .empty:
                    deckEmpty(
                        title: "No one new here",
                        message: "Check another community, or come back later."
                    )
                case let .error(message):
                    sectionError(message) {
                        if let communityId = discovery.selectedCommunityId {
                            Task { await discovery.selectCommunity(communityId) }
                        }
                    }
                case .loaded:
                    if let top = discovery.topCandidate {
                        let underlay = discovery.deckCandidates.dropFirst().first
                        ConnectDiscoverDeckView(
                            top: top,
                            underlay: underlay,
                            onPass: {
                                withAnimation(CLMotion.soft) {
                                    discovery.passCandidate(userId: top.id)
                                }
                            },
                            onViewProfile: { presentPeer(top) }
                        )
                        .clAppear()
                    } else {
                        deckEmpty(
                            title: "You’re all caught up",
                            message: "Pull to refresh, or pick another community."
                        )
                    }
                }
            }
        }
    }

    private func deckEmpty(title: String, message: String) -> some View {
        VStack(spacing: CLSpacing.sm) {
            Image(systemName: "person.2")
                .font(.system(size: 36, weight: .regular))
                .foregroundStyle(CLColor.inkMuted)
                .accessibilityHidden(true)
            Text(title)
                .font(CLTypography.title2)
                .foregroundStyle(CLColor.ink)
                .multilineTextAlignment(.center)
            Text(message)
                .font(CLTypography.subheadline)
                .foregroundStyle(CLColor.inkMuted)
                .multilineTextAlignment(.center)
        }
        .padding(CLSpacing.lg)
        .frame(maxWidth: .infinity)
        .background(CLColor.surfaceSoft)
        .clipShape(RoundedRectangle(cornerRadius: CLRadius.lg, style: .continuous))
    }

    // MARK: - Helpers

    private var blockConfirmTitle: String {
        if let name = blockTarget?.displayName {
            return "Block \(name)? They won’t appear in Connect for you."
        }
        return "Block this user? They won’t appear in Connect for you."
    }

    private var blockFilterWarningTitle: String {
        if tab.isBlockFilterReady {
            return "Blocked profiles may be out of date."
        }
        return "Connect is unavailable until blocked profiles can be checked."
    }

    private func presentPeer(_ user: User) {
        presentedPeer = PresentedPeer(userId: user.id, displayName: user.displayName)
    }

    private func selectedCommunityName(from communities: [Community]) -> String {
        communities.first(where: { $0.id == discovery.selectedCommunityId })?.name
            ?? "Select community"
    }

    private func sectionError(_ message: String, retry: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: CLSpacing.xs) {
            Text(message)
                .font(CLTypography.subheadline)
                .foregroundStyle(CLColor.inkSecondary)
                .accessibilityLabel("Error: \(message)")
            Button("Retry", action: retry)
                .font(CLTypography.subheadline.weight(.medium))
                .foregroundStyle(CLColor.primaryPressed)
                .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
                .accessibilityLabel("Retry loading section")
        }
    }
}

// MARK: - Navigation / presentation models

private enum ConnectDestination: Hashable {
    case likedYou
    case matches
}

private struct PresentedPeer: Identifiable, Equatable {
    let userId: String
    let displayName: String

    var id: String { userId }
}

private struct ModerationTarget: Identifiable, Equatable {
    let userId: String
    let displayName: String

    var id: String { userId }
}
