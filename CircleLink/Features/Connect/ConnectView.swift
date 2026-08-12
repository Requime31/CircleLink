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
                    // Separate items — one HStack of 44pt custom views breaks nav-bar vertical centering.
                    ToolbarItemGroup(placement: .topBarTrailing) {
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
                CLStatusBanner(
                    message: actionErrorMessage,
                    style: .error,
                    accessibilityPrefix: "Connect error"
                )
                .padding(.horizontal, CLSpacing.screenHorizontal)
                .padding(.top, CLSpacing.sm)
            }

            if let moderationMessage = viewModel.moderationMessage {
                CLStatusBanner(
                    message: moderationMessage,
                    style: .info
                )
                .padding(.horizontal, CLSpacing.screenHorizontal)
                .padding(.top, CLSpacing.sm)
                .onTapGesture { viewModel.clearModerationFeedback() }
            }

            deckSection
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Compact visual for nav bar. Hit target comes from system toolbar item (≥44pt).
    /// Do not force a 44×44 layout frame here — bar height is also ~44, so it pushes icons up.
    private func toolbarLabel(title: String, systemImage: String, badge: Int) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(CLColor.ink)
            .frame(width: 28, height: 28)
            .overlay(alignment: .topTrailing) {
                if badge > 0 {
                    Text(badge > 99 ? "99+" : "\(badge)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(CLColor.onPrimary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(CLColor.primary)
                        .clipShape(Capsule())
                        .offset(x: 6, y: -4)
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
            CLEmptyState(
                systemImage: "person.2",
                title: "No one new here",
                message: "Pull to refresh, or check back later."
            )
        case let .error(message):
            CLEmptyState(
                systemImage: "exclamationmark.triangle",
                title: "Couldn’t load people",
                message: message,
                actionTitle: "Retry",
                actionAccessibilityLabel: "Retry loading section"
            ) {
                Task { await viewModel.load() }
            }
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
                CLEmptyState(
                    systemImage: "person.2",
                    title: "You’re all caught up",
                    message: "Pull to refresh for more people."
                )
            }
        }
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
