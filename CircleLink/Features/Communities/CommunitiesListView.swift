import SwiftUI

/// Communities discovery list in Soft Orbit language. ViewModel bindings unchanged.
///
/// Data flow:
/// Appear / Refresh → CommunitiesViewModel.loadCommunities → CommunityRepository
///   → state → list / empty / error UI
/// Tap card → NavigationLink → CommunityDetailView
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
                        .foregroundStyle(CLColor.muted)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .empty:
                    emptyState
                case let .error(message):
                    errorState(message: message)
                case let .loaded(communities):
                    communitiesList(communities)
                }
            }
            .background(CLColor.canvas.ignoresSafeArea())
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
            .refreshable {
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
                    .accessibilityLabel(
                        "\(community.name), \(community.interestTag), \(community.memberCount) members"
                    )
                }
            }
            .padding(CLSpacing.base)
            .clAppear()
        }
    }

    private var emptyState: some View {
        CLEmptyState(
            systemImage: "person.3.fill",
            title: "Your orbits are waiting",
            message: "Interest circles will land here. Pull to refresh, or tap Refresh.",
            actionTitle: "Refresh",
            actionAccessibilityLabel: "Refresh communities list"
        ) {
            Task { await viewModel.loadCommunities() }
        }
    }

    private func errorState(message: String) -> some View {
        CLEmptyState(
            systemImage: "exclamationmark.triangle.fill",
            title: "Couldn't load communities",
            message: message,
            actionTitle: "Retry",
            actionAccessibilityLabel: "Retry loading communities",
            titleAccessibilityLabel: "Error: Couldn't load communities"
        ) {
            Task { await viewModel.loadCommunities() }
        }
    }
}

// MARK: - Card

private struct CommunityCardView: View {
    let community: Community

    var body: some View {
        HStack(alignment: .top, spacing: CLSpacing.md) {
            orbitMark
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: CLSpacing.sm) {
                HStack(alignment: .top, spacing: CLSpacing.sm) {
                    Text(community.name)
                        .font(CLTypography.section)
                        .foregroundStyle(CLColor.ink)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    CLMetaPill(title: community.interestTag)
                        .accessibilityHidden(true)
                }

                Text(community.description)
                    .font(CLTypography.callout)
                    .foregroundStyle(CLColor.muted)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)

                HStack(spacing: CLSpacing.xs) {
                    Circle()
                        .fill(CLColor.companion)
                        .frame(width: 6, height: 6)
                        .accessibilityHidden(true)
                    Text(memberCountLabel)
                        .font(CLTypography.caption)
                        .foregroundStyle(CLColor.mutedSoft)
                }
            }
        }
        .padding(CLSpacing.base)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clCardStyle()
    }

    private var orbitMark: some View {
        ZStack {
            Circle()
                .fill(CLColor.companionSoft)
                .frame(width: 44, height: 44)
            Circle()
                .stroke(CLColor.hairline, lineWidth: 1)
                .frame(width: 28, height: 28)
            Circle()
                .fill(CLColor.primary.opacity(0.85))
                .frame(width: 8, height: 8)
                .offset(x: 8, y: -6)
        }
    }

    private var memberCountLabel: String {
        community.memberCount == 1 ? "1 member" : "\(community.memberCount) members"
    }
}
