import SwiftUI

struct CommunitiesListView: View {
    @ObservedObject var viewModel: CommunitiesViewModel
    let makeDetailViewModel: (String) -> CommunityDetailViewModel
    let makePeerProfileSheet: (String, PeerProfileMode) -> PeerProfileSheet
    let onCommunitySelected: (String) -> Void
    let onOpenGroupChat: (String, String) -> Void

    @State private var showCreateSheet = false
    @State private var showAllCommunities = false
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
            .navigationDestination(isPresented: $showAllCommunities) {
                AllCommunitiesView(communities: viewModel.suggestedCommunities)
            }
            // onAppear (not only .task): re-runs when popping back from detail so counts stay fresh.
            .onAppear {
                viewModel.refreshOnAppear()
            }
        }
    }

    /// Search stays visible even when the query matches nothing.
    private var discoveryContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CLSpacing.xl) {
                searchField

                if viewModel.filteredCommunities.isEmpty {
                    filterEmptyState
                        .frame(maxWidth: .infinity)
                } else if viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    suggestedSection
                    newCirclesSection
                } else {
                    resultsSection
                }
            }
            .padding(.vertical, CLSpacing.sm)
            .clAppear()
        }
    }

    private var searchField: some View {
        HStack(spacing: CLSpacing.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(CLColor.inkMuted)
                .accessibilityHidden(true)
            TextField("Search circles…", text: $viewModel.searchQuery)
                .font(CLTypography.body)
                .foregroundStyle(CLColor.ink)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($isSearchFocused)
                .accessibilityLabel("Search communities")
        }
        .clTextFieldChrome(isFocused: isSearchFocused)
        .padding(.horizontal, CLSpacing.screenHorizontal)
    }

    private var suggestedSection: some View {
        VStack(alignment: .leading, spacing: CLSpacing.md) {
            HStack {
                Text("Suggested for you")
                    .font(CLTypography.title)
                    .foregroundStyle(CLColor.ink)
                Spacer()
                Button("See all") {
                    showAllCommunities = true
                }
                .font(CLTypography.callout.weight(.medium))
                .foregroundStyle(CLColor.primary)
                .accessibilityLabel("See all communities")
            }
            .padding(.horizontal, CLSpacing.screenHorizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: CLSpacing.md) {
                    ForEach(suggestedItems) { community in
                        NavigationLink(value: community.id) {
                            SuggestedCommunityCard(community: community)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(community.name), \(memberCountLabel(for: community))")
                    }
                }
                .padding(.horizontal, CLSpacing.screenHorizontal)
            }
        }
    }

    private var suggestedItems: [Community] {
        Array(viewModel.suggestedCommunities.prefix(3))
    }

    private var newCirclesSection: some View {
        communityRows(title: "New Circles", communities: viewModel.newCommunities)
    }

    private var resultsSection: some View {
        communityRows(title: "Results", communities: viewModel.filteredCommunities)
    }

    private func communityRows(title: String, communities: [Community]) -> some View {
        VStack(alignment: .leading, spacing: CLSpacing.md) {
            Text(title)
                .font(CLTypography.title)
                .foregroundStyle(CLColor.ink)
                .padding(.horizontal, CLSpacing.screenHorizontal)

            LazyVStack(spacing: CLSpacing.xs) {
                ForEach(communities) { community in
                    NavigationLink(value: community.id) {
                        CommunityRowView(community: community)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(community.name), \(memberCountLabel(for: community))")
                    .accessibilityHint("Opens community details")
                }
            }
            .padding(.horizontal, CLSpacing.screenHorizontal)
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

private struct AllCommunitiesView: View {
    let communities: [Community]
    @State private var searchQuery = ""
    @FocusState private var isSearchFocused: Bool

    private var filteredCommunities: [Community] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return communities }
        return communities.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.description.localizedCaseInsensitiveContains(query)
                || $0.interestTag.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: CLSpacing.md) {
                HStack(spacing: CLSpacing.xs) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(CLColor.inkMuted)
                        .accessibilityHidden(true)
                    TextField("Search circles…", text: $searchQuery)
                        .font(CLTypography.body)
                        .focused($isSearchFocused)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                .clTextFieldChrome(isFocused: isSearchFocused)

                if filteredCommunities.isEmpty {
                    CLEmptyState(
                        systemImage: "magnifyingglass",
                        title: "No communities match",
                        message: "Try a different search."
                    )
                } else {
                    LazyVStack(spacing: CLSpacing.xs) {
                        ForEach(filteredCommunities) { community in
                            NavigationLink(value: community.id) {
                                CommunityRowView(community: community)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(community.name)
                            .accessibilityHint("Opens community details")
                        }
                    }
                }
            }
            .padding(.horizontal, CLSpacing.screenHorizontal)
            .padding(.vertical, CLSpacing.md)
        }
        .clCanvasBackground()
        .navigationTitle("All Communities")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Card

private struct SuggestedCommunityCard: View {
    let community: Community

    var body: some View {
        VStack(spacing: CLSpacing.md) {
            CommunityArtworkView(community: community)
                .frame(width: 224, height: 224)

            VStack(spacing: CLSpacing.xxs) {
                Text(community.name)
                    .font(CLTypography.headline)
                    .foregroundStyle(CLColor.ink)
                    .lineLimit(1)
                Text(memberCountLabel)
                    .font(CLTypography.callout)
                    .foregroundStyle(CLColor.inkSecondary)
            }
        }
        .padding(CLSpacing.sm)
        .frame(width: 248)
        .background(CLColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: CLRadius.lg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: CLRadius.lg, style: .continuous).stroke(CLColor.hairline, lineWidth: 1))
    }

    private var memberCountLabel: String {
        community.memberCount == 1 ? "1 member" : "\(community.memberCount) members"
    }
}

private struct CommunityRowView: View {
    let community: Community

    var body: some View {
        HStack(spacing: CLSpacing.md) {
            CommunityArtworkView(community: community, cornerRadius: CLRadius.sm)
                .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: CLSpacing.xxs) {
                Text(community.name)
                    .font(CLTypography.headline)
                    .foregroundStyle(CLColor.ink)
                    .lineLimit(1)
                Text(memberCountLabel)
                    .font(CLTypography.callout)
                    .foregroundStyle(CLColor.inkSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(CLSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CLColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous).stroke(CLColor.hairline, lineWidth: 1))
        .contentShape(Rectangle())
    }

    private var memberCountLabel: String {
        community.memberCount == 1 ? "1 member" : "\(community.memberCount) members"
    }
}
