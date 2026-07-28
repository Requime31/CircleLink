import SwiftUI

struct CommunitiesListView: View {
    @ObservedObject var viewModel: CommunitiesViewModel
    let makeDetailViewModel: (String) -> CommunityDetailViewModel
    let onCommunitySelected: (String) -> Void
    let onOpenGroupChat: (String, String) -> Void

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
                case let .loaded(communities):
                    communitiesList(communities)
                }
            }
            .clCanvasBackground()
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
            // onAppear (not only .task): re-runs when popping back from detail so counts stay fresh.
            .onAppear {
                viewModel.refreshOnAppear()
            }
        }
    }

    @ViewBuilder
    private func communitiesList(_ communities: [Community]) -> some View {
        ScrollView {
            LazyVStack(spacing: CLSpacing.md) {
                ForEach(communities) { community in
                    NavigationLink(value: community.id) {
                        CommunityCardView(community: community)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(community.name), \(community.memberCount) members")
                }
            }
            .padding(.horizontal, CLSpacing.md)
            .padding(.vertical, CLSpacing.md)
            .clAppear()
        }
    }

    private var emptyState: some View {
        VStack(spacing: CLSpacing.sm) {
            Image(systemName: "person.3")
                .font(.system(size: 40))
                .foregroundStyle(CLColor.inkMuted)
                .padding(CLSpacing.md)
                .background(Circle().fill(CLColor.primarySoft))
                .accessibilityHidden(true)
            Text("No communities yet")
                .font(CLTypography.title2)
                .foregroundStyle(CLColor.ink)
            Text("Interest-based groups will appear here.")
                .font(CLTypography.subheadline)
                .foregroundStyle(CLColor.inkSecondary)
                .multilineTextAlignment(.center)
            Button("Refresh") {
                Task { await viewModel.loadCommunities() }
            }
            .buttonStyle(CLSecondaryButtonStyle())
            .padding(.top, CLSpacing.xs)
            .accessibilityLabel("Refresh communities list")
        }
        .padding(CLSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: CLSpacing.sm) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(CLColor.error)
                .padding(CLSpacing.md)
                .background(Circle().fill(CLColor.errorSoft))
                .accessibilityHidden(true)
            Text(message)
                .font(CLTypography.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(CLColor.inkSecondary)
                .accessibilityLabel("Error: \(message)")
            Button("Retry") {
                Task { await viewModel.loadCommunities() }
            }
            .buttonStyle(CLSecondaryButtonStyle())
            .padding(.top, CLSpacing.xs)
            .accessibilityLabel("Retry loading communities")
        }
        .padding(CLSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct CommunityCardView: View {
    let community: Community

    var body: some View {
        VStack(alignment: .leading, spacing: CLSpacing.sm) {
            HStack(alignment: .top, spacing: CLSpacing.xs) {
                Text(community.name)
                    .font(CLTypography.headline)
                    .foregroundStyle(CLColor.ink)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: CLSpacing.xs)

                Text(community.interestTag)
                    .font(CLTypography.caption)
                    .foregroundStyle(CLColor.ink)
                    .padding(.horizontal, CLSpacing.sm)
                    .padding(.vertical, CLSpacing.xxs)
                    .background(CLColor.primarySoft)
                    .clipShape(Capsule())
            }

            Text(community.description)
                .font(CLTypography.subheadline)
                .foregroundStyle(CLColor.inkSecondary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)

            Text(memberCountLabel)
                .font(CLTypography.footnote)
                .foregroundStyle(CLColor.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clCardStyle()
    }

    private var memberCountLabel: String {
        community.memberCount == 1 ? "1 member" : "\(community.memberCount) members"
    }
}
