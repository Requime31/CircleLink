import SwiftUI

struct CommunitiesListView: View {
    @ObservedObject var viewModel: CommunitiesViewModel
    let makeDetailViewModel: (String) -> CommunityDetailViewModel
    let makePeerProfileSheet: (String, PeerProfileMode) -> PeerProfileSheet
    let onCommunitySelected: (String) -> Void
    let onOpenGroupChat: (String, String) -> Void

    @State private var showCreateSheet = false
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .idle, .loading:
                    CLLoadingState(message: "Loading communities…")
                case .empty:
                    emptyState
                case let .error(message):
                    errorState(message: message)
                case .loaded:
                    discoveryContent
                }
            }
            .clCanvasBackground()
            .navigationTitle("Communities")
            .navigationBarTitleDisplayMode(.large)
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

    /// Search + chips stay visible even when filter matches nothing.
    private var discoveryContent: some View {
        let filtered = viewModel.filteredCommunities
        return VStack(spacing: 0) {
            discoveryControls
                .padding(.horizontal, CLSpacing.screenHorizontal)
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
                    .focused($isSearchFocused)
                    .accessibilityLabel("Search communities")
            }
            .clTextFieldChrome(isFocused: isSearchFocused)

            if !viewModel.availableInterestTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: CLSpacing.xs) {
                        CLChip(
                            title: "All",
                            isSelected: viewModel.selectedInterestTag == nil,
                            accessibilityLabelText: "All interests",
                            accessibilityHintText: "Double tap to filter communities"
                        ) {
                            viewModel.selectedInterestTag = nil
                        }

                        ForEach(viewModel.availableInterestTags, id: \.self) { tag in
                            CLChip(
                                title: tag,
                                isSelected: viewModel.selectedInterestTag == tag,
                                accessibilityLabelText: "\(tag) interest",
                                accessibilityHintText: "Double tap to filter communities"
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
            .padding(.horizontal, CLSpacing.screenHorizontal)
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
            actionTitle: "Retry",
            actionAccessibilityLabel: "Retry loading communities",
            titleAccessibilityLabel: "Error: \(message)"
        ) {
            Task { await viewModel.loadCommunities() }
        }
    }

    private func memberCountLabel(for community: Community) -> String {
        community.memberCount == 1 ? "1 member" : "\(community.memberCount) members"
    }
}

// MARK: - Card

private struct CommunityCardView: View {
    let community: Community

    var body: some View {
        VStack(alignment: .leading, spacing: CLSpacing.sm) {
            HStack(alignment: .top, spacing: CLSpacing.xs) {
                Text(community.name)
                    .font(CLTypography.title2)
                    .foregroundStyle(CLColor.ink)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: CLSpacing.xs)

                CLChip(
                    title: community.interestTag,
                    isEmphasized: true,
                    accessibilityLabelText: "Interest: \(community.interestTag)"
                )
            }

            Text(community.description)
                .font(CLTypography.subheadline)
                .foregroundStyle(CLColor.inkSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            HStack(spacing: CLSpacing.xs) {
                Image(systemName: "person.2.fill")
                    .font(.caption)
                    .foregroundStyle(CLColor.inkMuted)
                    .accessibilityHidden(true)
                Text(memberCountLabel)
                    .font(CLTypography.footnote)
                    .foregroundStyle(CLColor.inkMuted)

                Spacer(minLength: CLSpacing.xs)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(CLColor.inkDisabled)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .clCardStyle()
    }

    private var memberCountLabel: String {
        community.memberCount == 1 ? "1 member" : "\(community.memberCount) members"
    }
}

