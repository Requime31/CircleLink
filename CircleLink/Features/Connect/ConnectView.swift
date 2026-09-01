import SwiftUI
import UIKit

/// Connect tab root = Discover (inline profile + swipe).
/// Liked you / Matches are push destinations.
struct ConnectView: View {
    @ObservedObject var viewModel: ConnectViewModel
    let makePeerProfileSheet: (String, PeerProfileMode) -> PeerProfileSheet

    @State private var reportTarget: ModerationTarget?
    @State private var blockTarget: ModerationTarget?
    @State private var presentedPeer: PresentedPeer?
    @State private var swipeFeedback: ConnectSwipeFeedback?
    @State private var swipeFeedbackDismissTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            discoverContent
                .clCanvasBackground()
                .overlay(alignment: .top) {
                    if let swipeFeedback {
                        ConnectSwipeFeedbackView(feedback: swipeFeedback)
                            .padding(.horizontal, CLSpacing.screenHorizontal)
                            .padding(.top, CLSpacing.sm)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .allowsHitTesting(false)
                            .zIndex(2)
                    }
                }
                .navigationTitle("Connect")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            viewModel.undoLastPass()
                        } label: {
                            Image(systemName: "arrow.uturn.backward")
                        }
                        .disabled(!viewModel.canUndoPass)
                        .accessibilityLabel("Undo last pass")
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            NavigationLink(value: ConnectDestination.outgoingLikes) {
                                Label(
                                    menuTitle("People You Liked", count: viewModel.outgoingPendingCount),
                                    systemImage: "paperplane"
                                )
                            }

                            NavigationLink(value: ConnectDestination.likedYou) {
                                Label(
                                    menuTitle("Liked You", count: viewModel.incomingCount),
                                    systemImage: "heart"
                                )
                            }

                            NavigationLink(value: ConnectDestination.matches) {
                                Label(
                                    menuTitle("Matches", count: viewModel.matchedCount),
                                    systemImage: "link"
                                )
                            }
                        } label: {
                            toolbarLabel(
                                title: "Connect updates",
                                systemImage: "person.2",
                                showsIndicator: connectUpdatesCount > 0
                            )
                        }
                        .accessibilityLabel(connectUpdatesAccessibilityLabel)
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
                    case .outgoingLikes:
                        OutgoingLikesView(
                            viewModel: viewModel,
                            onSelectPeer: { item in
                                presentedPeer = .outgoing(item)
                            },
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
                .onDisappear {
                    swipeFeedbackDismissTask?.cancel()
                    swipeFeedbackDismissTask = nil
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
                .sheet(item: $blockTarget) { target in
                    BlockConfirmationView(
                        peerName: target.displayName,
                        isBlocking: viewModel.moderatingUserId == target.userId,
                        errorMessage: viewModel.blockErrorMessage,
                        onCancel: { blockTarget = nil },
                        onBlock: {
                            Task {
                                if await viewModel.block(userId: target.userId) {
                                    blockTarget = nil
                                }
                            }
                        }
                    )
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

    /// Uses the symbol's intrinsic proportions; the indicator sits above its top-right edge.
    private func toolbarLabel(title: String, systemImage: String, showsIndicator: Bool) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(CLColor.ink)
            .frame(width: 28, height: 28)
            .overlay(alignment: .topTrailing) {
                if showsIndicator {
                    Circle()
                        .fill(CLColor.primary)
                        .frame(width: 7, height: 7)
                        .offset(x: 3, y: -2)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(title)
    }

    private var connectUpdatesCount: Int {
        viewModel.outgoingPendingCount + viewModel.incomingCount + viewModel.matchedCount
    }

    private var connectUpdatesAccessibilityLabel: String {
        connectUpdatesCount == 0
            ? "Connect updates"
            : "Connect updates, \(connectUpdatesCount) items"
    }

    private func menuTitle(_ title: String, count: Int) -> String {
        count == 0 ? title : "\(title) (\(count))"
    }

    // MARK: - Deck

    @ViewBuilder
    private var deckSection: some View {
        switch viewModel.candidatesState {
        case .idle, .loading:
            CLLoadingState(message: "Loading people…")
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
                    next: viewModel.nextCandidate,
                    following: viewModel.followingCandidate,
                    communities: viewModel.topCandidateCommunities,
                    isSendingConnect: viewModel.isSendingConnect,
                    onPass: { userId in
                        viewModel.passCandidate(userId: userId)
                        showSwipeFeedback(.passed(name: top.displayName))
                    },
                    onSayHi: { userId in
                        let didStart = viewModel.sayHi(to: userId)
                        if didStart {
                            showSwipeFeedback(.saidHi(name: top.displayName))
                        }
                        return didStart
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

    private func showSwipeFeedback(_ feedback: ConnectSwipeFeedback) {
        swipeFeedbackDismissTask?.cancel()
        withAnimation(.easeOut(duration: 0.2)) {
            swipeFeedback = feedback
        }
        UIAccessibility.post(notification: .announcement, argument: feedback.accessibilityMessage)

        swipeFeedbackDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.2)) {
                swipeFeedback = nil
            }
            swipeFeedbackDismissTask = nil
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

private enum ConnectSwipeFeedback: Equatable {
    case passed(name: String)
    case saidHi(name: String)

    var message: String {
        switch self {
        case let .passed(name): return "Passed \(name)"
        case let .saidHi(name): return "Say Hi sent to \(name)"
        }
    }

    var accessibilityMessage: String { message }

    var systemImage: String {
        switch self {
        case .passed: return "arrow.left"
        case .saidHi: return "hand.wave.fill"
        }
    }

    var tint: Color {
        switch self {
        case .passed: return CLColor.inkSecondary
        case .saidHi: return CLColor.primary
        }
    }
}

private struct ConnectSwipeFeedbackView: View {
    let feedback: ConnectSwipeFeedback

    var body: some View {
        HStack(spacing: CLSpacing.sm) {
            Image(systemName: feedback.systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(feedback.tint)

            Text(feedback.message)
                .font(CLTypography.footnote.weight(.semibold))
                .foregroundStyle(CLColor.ink)
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, CLSpacing.md)
        .padding(.vertical, CLSpacing.sm)
        .background(CLColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous)
                .stroke(CLColor.hairline, lineWidth: 1)
        }
        .shadow(color: CLColor.ink.opacity(0.08), radius: 10, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(feedback.accessibilityMessage)
    }
}

// MARK: - Navigation / presentation models

enum ConnectDestination: Hashable {
    case likedYou
    case matches
    case outgoingLikes
}

struct PresentedPeer: Identifiable, Equatable {
    enum Mode: Equatable {
        case likedYou(requestId: String)
        case match
        case outgoingPending
    }

    let userId: String
    let displayName: String
    let mode: Mode

    var id: String { userId }

    static func outgoing(_ item: OutgoingConnectRequestItem) -> Self {
        Self(
            userId: item.peer.id,
            displayName: item.peer.displayName,
            mode: .outgoingPending
        )
    }

    var profileMode: PeerProfileMode {
        switch mode {
        case let .likedYou(requestId):
            return .likedYou(requestId: requestId)
        case .match:
            return .social
        case .outgoingPending:
            return .readOnly
        }
    }
}

private struct ModerationTarget: Identifiable, Equatable {
    let userId: String
    let displayName: String

    var id: String { userId }
}
