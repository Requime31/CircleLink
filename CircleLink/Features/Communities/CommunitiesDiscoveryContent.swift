import SwiftUI

/// Search + interest chips + filtered community cards for the Communities tab.
struct CommunitiesDiscoveryContent: View {
    @ObservedObject var viewModel: CommunitiesViewModel

    var body: some View {
        let filtered = viewModel.filteredCommunities
        return VStack(spacing: 0) {
            discoveryControls
                .padding(.horizontal, CLSpacing.md)
                .padding(.top, CLSpacing.sm)
                .padding(.bottom, CLSpacing.xs)

            if filtered.isEmpty {
                filterEmptyState
            } else {
                communitiesList(filtered)
            }
        }
    }

    private var discoveryControls: some View {
        VStack(alignment: .leading, spacing: CLSpacing.sm) {
            HStack(spacing: CLSpacing.xs) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(CLColor.inkMuted)
                    .accessibilityHidden(true)
                TextField("Search communities", text: $viewModel.searchQuery)
                    .font(CLTypography.body)
                    .foregroundStyle(CLColor.ink)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityLabel("Search communities")
            }
            .clTextFieldChrome()

            if !viewModel.availableInterestTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: CLSpacing.xs) {
                        InterestFilterChip(
                            title: "All",
                            isSelected: viewModel.selectedInterestTag == nil
                        ) {
                            viewModel.selectedInterestTag = nil
                        }

                        ForEach(viewModel.availableInterestTags, id: \.self) { tag in
                            InterestFilterChip(
                                title: tag,
                                isSelected: viewModel.selectedInterestTag == tag
                            ) {
                                viewModel.selectedInterestTag = tag
                            }
                        }
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Filter by interest")
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
                    .accessibilityLabel(
                        "\(community.name), \(community.interestTag), \(memberCountLabel(for: community))"
                    )
                    .accessibilityHint("Opens community details")
                }
            }
            .padding(.horizontal, CLSpacing.md)
            .padding(.vertical, CLSpacing.md)
            .clAppear()
        }
    }

    private var filterEmptyState: some View {
        CLEmptyState(
            systemImage: "magnifyingglass",
            title: "No communities match",
            message: "Try a different search or clear the interest filter.",
            actionTitle: "Clear filters",
            actionAccessibilityLabel: "Clear search and interest filters"
        ) {
            viewModel.clearFilters()
        }
    }

    private func memberCountLabel(for community: Community) -> String {
        community.memberCount == 1 ? "1 member" : "\(community.memberCount) members"
    }
}
