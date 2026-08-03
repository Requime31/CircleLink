import SwiftUI

/// Connect tab root = Discover (community + swipe deck).
/// Liked you / Matches are push destinations. Connect action lives in PeerProfileSheet.
struct ConnectView: View {
    @ObservedObject var tab: ConnectTabModel
    let makePeerProfileSheet: (String, String?) -> PeerProfileSheet

    @State private var reportTarget: ModerationTarget?
    @State private var blockTarget: ModerationTarget?
    @State private var presentedPeer: PresentedPeer?

    var body: some View {
        NavigationStack {
            ConnectDiscoverContent(tab: tab, onViewProfile: presentPeer)
                .clCanvasBackground()
                .navigationTitle("Connect")
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        NavigationLink(value: ConnectDestination.likedYou) {
                            ConnectToolbarBadgeLabel(
                                title: "Liked you",
                                systemImage: "heart",
                                badge: tab.incomingCount
                            )
                        }
                        .accessibilityLabel(likedYouAccessibilityLabel)
                        .disabled(!tab.isBlockFilterReady)

                        NavigationLink(value: ConnectDestination.matches) {
                            ConnectToolbarBadgeLabel(
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
                    destinationView(destination)
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

    @ViewBuilder
    private func destinationView(_ destination: ConnectDestination) -> some View {
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

    private var blockConfirmTitle: String {
        if let name = blockTarget?.displayName {
            return "Block \(name)? They won’t appear in Connect for you."
        }
        return "Block this user? They won’t appear in Connect for you."
    }

    private func presentPeer(_ user: User) {
        presentedPeer = PresentedPeer(userId: user.id, displayName: user.displayName)
    }
}
