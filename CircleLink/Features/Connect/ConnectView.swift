import SwiftUI

/// Connect tab root = Discover (inline profile + swipe).
/// Liked you / Matches are push destinations.
struct ConnectView: View {
    @ObservedObject var viewModel: ConnectViewModel
    let makePeerProfileSheet: (String, PeerProfileMode) -> PeerProfileSheet

    @State private var reportTarget: ModerationTarget?
    @State private var blockTarget: ModerationTarget?
    @State private var presentedPeer: PresentedPeer?

    var body: some View {
        NavigationStack {
            discoverContent
                .clCanvasBackground()
                .navigationTitle("Connect")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        HStack(spacing: CLSpacing.sm) {
                            NavigationLink(value: ConnectDestination.likedYou) {
                                toolbarLabel(
                                    title: "Liked you",
                                    systemImage: "heart",
                                    badge: viewModel.incomingCount
                                )
                            }
                            .accessibilityLabel(likedYouAccessibilityLabel)

                            NavigationLink(value: ConnectDestination.matches) {
                                toolbarLabel(
                                    title: "Matches",
                                    systemImage: "link",
                                    badge: viewModel.matchedCount
                                )
                            }
                            .accessibilityLabel(matchesAccessibilityLabel)
                        }
                    }
                }
                .navigationDestination(for: ConnectDestination.self) { destination in
                    switch destination {
                    case .likedYou:
                        LikedYouView(
                            viewModel: viewModel,
                            onSelectPeer: { item in
                                presentPeer(
                                    userId: item.peer.id,
                                    displayName: item.peer.displayName,
                                    mode: .likedYou(requestId: item.request.id)
                                )
                            },
                            onReport: { userId, name in
                                reportTarget = ModerationTarget(userId: userId, displayName: name)
                            },
                            onBlock: { userId, name in
                                blockTarget = ModerationTarget(userId: userId, displayName: name)
                            }
                        )
                    case .matches:
                        MatchesView(
                            viewModel: viewModel,
                            onSelectPeer: { presentMatchPeer($0) },
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
                    await viewModel.loadIfNeeded()
                }
                .refreshable {
                    await viewModel.load()
                }
                .sheet(item: $presentedPeer) { peer in
                    peerSheet(for: peer)
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
                                    await viewModel.report(userId: reportTarget.userId, reason: reason)
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
                                await viewModel.block(userId: blockTarget.userId)
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
        VStack(spacing: 0) {
            if let actionErrorMessage = viewModel.actionErrorMessage {
                Text(actionErrorMessage)
                    .font(CLTypography.footnote)
                    .foregroundStyle(CLColor.error)
                    .padding(CLSpacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(CLColor.errorSoft)
                    .padding(.horizontal, CLSpacing.md)
                    .padding(.top, CLSpacing.sm)
                    .accessibilityLabel("Connect error: \(actionErrorMessage)")
            }

            if let moderationMessage = viewModel.moderationMessage {
                Text(moderationMessage)
                    .font(CLTypography.footnote)
                    .foregroundStyle(CLColor.inkSecondary)
                    .padding(CLSpacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(CLColor.surfaceSoft)
                    .clipShape(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous))
                    .padding(.horizontal, CLSpacing.md)
                    .padding(.top, CLSpacing.sm)
                    .onTapGesture { viewModel.clearModerationFeedback() }
            }

            deckSection
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func toolbarLabel(title: String, systemImage: String, badge: Int) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(CLColor.ink)
            .frame(width: 36, height: 36)
            .overlay(alignment: .topTrailing) {
                if badge > 0 {
                    Text(badge > 99 ? "99+" : "\(badge)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(CLColor.onPrimary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(CLColor.primary)
                        .clipShape(Capsule())
                        .offset(x: 4, y: -2)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(title)
    }

    private var likedYouAccessibilityLabel: String {
        let count = viewModel.incomingCount
        if count == 0 { return "Liked you" }
        return "Liked you, \(count) pending"
    }

    private var matchesAccessibilityLabel: String {
        let count = viewModel.matchedCount
        if count == 0 { return "Matches" }
        return "Matches, \(count)"
    }

    // MARK: - Deck

    @ViewBuilder
    private var deckSection: some View {
        switch viewModel.candidatesState {
        case .idle, .loading:
            ProgressView("Loading people…")
                .tint(CLColor.primary)
                .foregroundStyle(CLColor.inkMuted)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .empty:
            deckEmpty(
                title: "No one new here",
                message: "Pull to refresh, or check back later."
            )
        case let .error(message):
            sectionError(message) {
                Task { await viewModel.load() }
            }
            .padding(CLSpacing.md)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        case .loaded:
            if let top = viewModel.topCandidate {
                ConnectDiscoverDeckView(
                    top: top,
                    communities: viewModel.topCandidateCommunities,
                    canUndo: viewModel.canUndoPass,
                    isSendingConnect: viewModel.isSendingConnect,
                    onPass: {
                        viewModel.passCandidate(userId: top.id)
                    },
                    onSayHi: {
                        Task { await viewModel.sayHi(to: top.id) }
                    },
                    onUndo: {
                        viewModel.undoLastPass()
                    }
                )
            } else {
                deckEmpty(
                    title: "You’re all caught up",
                    message: "Pull to refresh for more people."
                )
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Presentation (Liked You + Matches only)

    @ViewBuilder
    private func peerSheet(for peer: PresentedPeer) -> some View {
        makePeerProfileSheet(peer.userId, peer.profileMode)
            .onDisappear {
                Task { await viewModel.refreshAfterPeerSheet() }
            }
    }

    private var blockConfirmTitle: String {
        if let name = blockTarget?.displayName {
            return "Block \(name)? They won’t appear in Connect for you."
        }
        return "Block this user? They won’t appear in Connect for you."
    }

    private func presentPeer(userId: String, displayName: String, mode: PeerProfileMode) {
        guard case let .likedYou(requestId) = mode else { return }
        presentedPeer = PresentedPeer(
            userId: userId,
            displayName: displayName,
            mode: .likedYou(requestId: requestId)
        )
    }

    private func presentMatchPeer(_ user: User) {
        presentedPeer = PresentedPeer(
            userId: user.id,
            displayName: user.displayName,
            mode: .match
        )
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
    enum Mode: Equatable {
        case likedYou(requestId: String)
        case match
    }

    let userId: String
    let displayName: String
    let mode: Mode

    var id: String { userId }

    var profileMode: PeerProfileMode {
        switch mode {
        case let .likedYou(requestId):
            return .likedYou(requestId: requestId)
        case .match:
            return .social
        }
    }
}

private struct ModerationTarget: Identifiable, Equatable {
    let userId: String
    let displayName: String

    var id: String { userId }
}
