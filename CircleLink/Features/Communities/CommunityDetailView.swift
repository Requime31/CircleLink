import SwiftUI

struct CommunityDetailView: View {
    @ObservedObject var viewModel: CommunityDetailViewModel
    @ObservedObject var feedViewModel: CommunityFeedViewModel
    /// Called with `(chatId, title)` after group chat is created or opened.
    let onOpenGroupChat: (String, String) -> Void
    /// Builds peer profile sheet. Pass `communityId` so Connect works.
    let makePeerProfileSheet: (String, String?) -> PeerProfileSheet

    @State private var presentedPeer: PeerSheetItem?
    @State private var showComposeSheet = false
    @State private var postPendingDelete: CommunityPostItem?

    var body: some View {
        Group {
            switch viewModel.communityState {
            case .idle, .loading:
                ProgressView("Loading community…")
                    .tint(CLColor.primary)
                    .foregroundStyle(CLColor.inkMuted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case let .error(message):
                errorState(message: message)
            case .empty:
                errorState(message: "Community not found.")
            case let .loaded(community):
                detailContent(community: community)
            }
        }
        .clCanvasBackground()
        .navigationTitle(viewModel.communityState.loadedValue?.name ?? "Community")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $presentedPeer) { peer in
            makePeerProfileSheet(peer.userId, viewModel.communityId)
        }
        .sheet(isPresented: $showComposeSheet) {
            ComposeCommunityPostSheet(feedViewModel: feedViewModel) {
                showComposeSheet = false
            }
        }
        .confirmationDialog(
            "Delete this post?",
            isPresented: Binding(
                get: { postPendingDelete != nil },
                set: { if !$0 { postPendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Post", role: .destructive) {
                guard let item = postPendingDelete else { return }
                postPendingDelete = nil
                Task { await feedViewModel.deletePost(item) }
            }
            Button("Cancel", role: .cancel) {
                postPendingDelete = nil
            }
        } message: {
            Text("This can’t be undone.")
        }
        .task {
            await viewModel.load()
            feedViewModel.syncMembership(isMember: viewModel.isMember)
        }
        .onChange(of: viewModel.isMember) { isMember in
            feedViewModel.syncMembership(isMember: isMember)
        }
        .onDisappear {
            feedViewModel.onDisappear()
        }
    }

    @ViewBuilder
    private func detailContent(community: Community) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CLSpacing.xl) {
                CommunityDetailHeaderSection(community: community)
                CommunityMembershipSection(
                    viewModel: viewModel,
                    onOpenGroupChat: onOpenGroupChat
                )
                CommunityFeedSection(
                    feedViewModel: feedViewModel,
                    isMember: viewModel.isMember,
                    onJoinTapped: {
                        Task { await viewModel.join() }
                    },
                    onComposeTapped: {
                        feedViewModel.clearError()
                        showComposeSheet = true
                    },
                    onAuthorTap: { userId in
                        presentedPeer = PeerSheetItem(userId: userId)
                    },
                    onDelete: { item in
                        postPendingDelete = item
                    }
                )
                CommunityAboutSection(community: community)
                CommunityMembersSection(
                    viewModel: viewModel,
                    onSelectPeer: { userId in
                        presentedPeer = PeerSheetItem(userId: userId)
                    }
                )
            }
            .padding(.horizontal, CLSpacing.md)
            .padding(.vertical, CLSpacing.lg)
            .clAppear()
        }
    }

    private func errorState(message: String) -> some View {
        CLEmptyState(
            systemImage: "exclamationmark.triangle",
            title: message,
            systemImageColor: CLColor.error,
            actionTitle: "Retry",
            actionAccessibilityLabel: "Retry loading community",
            titleAccessibilityLabel: "Error: \(message)"
        ) {
            Task { await viewModel.load() }
        }
    }
}

/// Sheet identity for `.sheet(item:)`.
struct PeerSheetItem: Identifiable {
    let userId: String
    var id: String { userId }
}

private extension ViewState {
    var loadedValue: T? {
        if case let .loaded(value) = self {
            return value
        }
        return nil
    }
}
