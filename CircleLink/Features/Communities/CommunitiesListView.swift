import SwiftUI

struct CommunitiesListView: View {
    @ObservedObject var viewModel: CommunitiesViewModel
    let makeDetailViewModel: (String) -> CommunityDetailViewModel
    let onCommunitySelected: (String) -> Void
    let onOpenGroupChat: (String) -> Void

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .idle, .loading:
                    ProgressView("Loading communities…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .empty:
                    emptyState
                case let .error(message):
                    errorState(message: message)
                case let .loaded(communities):
                    communitiesList(communities)
                }
            }
            .navigationTitle("Communities")
            .navigationDestination(for: String.self) { communityId in
                CommunityDetailView(
                    viewModel: makeDetailViewModel(communityId),
                    onOpenGroupChat: onOpenGroupChat
                )
                .onAppear {
                    onCommunitySelected(communityId)
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
            LazyVStack(spacing: 16) {
                ForEach(communities) { community in
                    NavigationLink(value: community.id) {
                        CommunityCardView(community: community)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(community.name), \(community.memberCount) members")
                }
            }
            .padding(16)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.3")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("No communities yet")
                .font(.title3)
            Text("Interest-based groups will appear here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Refresh") {
                Task { await viewModel.loadCommunities() }
            }
            .accessibilityLabel("Refresh communities list")
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Error: \(message)")
            Button("Retry") {
                Task { await viewModel.loadCommunities() }
            }
            .accessibilityLabel("Retry loading communities")
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct CommunityCardView: View {
    let community: Community

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Text(community.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                Spacer()

                Text(community.interestTag)
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(Capsule())
            }

            Text(community.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)

            Text(memberCountLabel)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var memberCountLabel: String {
        community.memberCount == 1 ? "1 member" : "\(community.memberCount) members"
    }
}
