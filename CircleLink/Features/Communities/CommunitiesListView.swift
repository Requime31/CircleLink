import SwiftUI

struct CommunitiesListView: View {
    @ObservedObject var viewModel: CommunitiesViewModel
    let makeDetailViewModel: (String) -> CommunityDetailViewModel
    let makeFeedViewModel: (String) -> CommunityFeedViewModel
    let makePeerProfileSheet: (String, String?) -> PeerProfileSheet
    let onCommunitySelected: (String) -> Void
    let onOpenGroupChat: (String, String) -> Void

    @State private var showCreateSheet = false

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .idle, .loading:
                    ProgressView("Loading communities…")
                        .tint(CLColor.primary)
                        .foregroundStyle(CLColor.inkMuted)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .empty:
                    emptyState
                case let .error(message):
                    errorState(message: message)
                case .loaded:
                    CommunitiesDiscoveryContent(viewModel: viewModel)
                }
            }
            .clCanvasBackground()
            .navigationTitle("Communities")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Create community")
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                CreateCommunitySheet(viewModel: viewModel) {
                    showCreateSheet = false
                }
            }
            .navigationDestination(for: String.self) { communityId in
                CommunityDetailView(
                    viewModel: makeDetailViewModel(communityId),
                    feedViewModel: makeFeedViewModel(communityId),
                    onOpenGroupChat: onOpenGroupChat,
                    makePeerProfileSheet: makePeerProfileSheet
                )
                .onAppear {
                    onCommunitySelected(communityId)
                }
            }
            // onAppear (not only .task): re-runs when popping back from detail so counts stay fresh.
            .onAppear {
                viewModel.refreshOnAppear()
            }
        }
    }

    private var emptyState: some View {
        CLEmptyState(
            systemImage: "person.3",
            title: "No communities yet",
            message: "Interest-based groups will appear here.",
            actionTitle: "Refresh",
            actionAccessibilityLabel: "Refresh communities list"
        ) {
            Task { await viewModel.loadCommunities() }
        }
    }

    private func errorState(message: String) -> some View {
        CLEmptyState(
            systemImage: "exclamationmark.triangle",
            title: message,
            systemImageColor: CLColor.error,
            actionTitle: "Retry",
            actionAccessibilityLabel: "Retry loading communities",
            titleAccessibilityLabel: "Error: \(message)"
        ) {
            Task { await viewModel.loadCommunities() }
        }
    }
}
