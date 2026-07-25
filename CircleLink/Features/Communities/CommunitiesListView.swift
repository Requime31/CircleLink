import SwiftUI

struct CommunitiesListView: View {
    @ObservedObject var viewModel: CommunitiesViewModel
    let makeDetailViewModel: (String) -> CommunityDetailViewModel
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
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .empty:
                    emptyState
                case let .error(message):
                    errorState(message: message)
                case let .loaded(communities):
                    communitiesList(communities)
                }
            }
            .background(CLColor.canvas)
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
            .navigationDestination(for: String.self) { communityId in
                CommunityDetailView(
                    viewModel: makeDetailViewModel(communityId),
                    onOpenGroupChat: onOpenGroupChat
                )
                .onAppear {
                    onCommunitySelected(communityId)
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                CreateCommunitySheet(viewModel: viewModel) {
                    showCreateSheet = false
                }
            }
            .task {
                await viewModel.loadCommunities()
            }
        }
    }

    @ViewBuilder
    private func communitiesList(_ communities: [Community]) -> some View {
        ScrollView {
            LazyVStack(spacing: CLSpacing.base) {
                ForEach(communities) { community in
                    NavigationLink(value: community.id) {
                        CommunityCardView(community: community)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(community.name), \(community.memberCount) members")
                }
            }
            .padding(CLSpacing.base)
        }
    }

    private var emptyState: some View {
        CLEmptyState(
            systemImage: "person.3",
            title: "No communities yet",
            message: "Create one around an interest to start meeting people.",
            actionTitle: "Create community",
            actionAccessibilityLabel: "Create community"
        ) {
            showCreateSheet = true
        }
    }

    private func errorState(message: String) -> some View {
        CLEmptyState(
            systemImage: "exclamationmark.triangle",
            title: message,
            actionTitle: "Retry",
            actionAccessibilityLabel: "Retry loading communities",
            titleAccessibilityLabel: "Error: \(message)"
        ) {
            Task { await viewModel.loadCommunities() }
        }
    }
}

private struct CommunityCardView: View {
    let community: Community

    var body: some View {
        VStack(alignment: .leading, spacing: CLSpacing.md) {
            HStack(alignment: .top) {
                Text(community.name)
                    .font(CLTypography.section)
                    .foregroundStyle(CLColor.ink)
                    .multilineTextAlignment(.leading)

                Spacer()

                Text(community.interestTag)
                    .font(CLTypography.callout)
                    .foregroundStyle(CLColor.ink)
                    .padding(.horizontal, CLSpacing.md)
                    .padding(.vertical, CLSpacing.sm)
                    .background(CLColor.surfaceSoft)
                    .clipShape(Capsule())
            }

            Text(community.description)
                .font(CLTypography.callout)
                .foregroundStyle(CLColor.muted)
                .lineLimit(3)
                .multilineTextAlignment(.leading)

            Text(memberCountLabel)
                .font(CLTypography.caption)
                .foregroundStyle(CLColor.muted)
        }
        .padding(CLSpacing.base)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CLColor.surfaceSoft)
        .clipShape(RoundedRectangle(cornerRadius: CLRadius.md))
    }

    private var memberCountLabel: String {
        community.memberCount == 1 ? "1 member" : "\(community.memberCount) members"
    }
}
