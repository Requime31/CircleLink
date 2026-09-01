import SwiftUI

struct CommunitiesListView: View {
    @ObservedObject var viewModel: CommunitiesViewModel
    let makeDetailViewModel: (String) -> CommunityDetailViewModel
    let makePeerProfileSheet: (String, PeerProfileMode) -> PeerProfileSheet
    let onCommunitySelected: (String) -> Void
    let onOpenGroupChat: (String, String) -> Void

    @State private var showCreateSheet = false
    @State private var navigationPath: [CommunitiesRoute] = []
    @State private var carouselViewportWidth: CGFloat = 0
    @FocusState private var isSearchFocused: Bool

    private let carouselCoordinateSpace = "communities-popular-carousel"

    var body: some View {
        NavigationStack(path: $navigationPath) {
            rootContent
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
            .navigationDestination(for: CommunitiesRoute.self) { route in
                switch route {
                case let .allCommunities(sortOrder):
                    AllCommunitiesView(
                        communities: viewModel.allCommunities,
                        initialSortOrder: sortOrder,
                        onCommunitySelected: { community in
                            navigate(to: detailRoute(for: community))
                        }
                    )
                case let .communityDetail(id, name):
                    CommunityDetailView(
                        viewModel: makeDetailViewModel(id),
                        initialTitle: name,
                        onOpenGroupChat: onOpenGroupChat,
                        makePeerProfileSheet: makePeerProfileSheet
                    )
                    .navigationTitle(name)
                    .navigationBarTitleDisplayMode(.inline)
                    .onAppear {
                        onCommunitySelected(id)
                    }
                }
            }
            // onAppear (not only .task): re-runs when popping back from detail so counts stay fresh.
            .onAppear {
                viewModel.refreshOnAppear()
            }
        }
    }

    /// Navigation chrome, search, and known categories remain stable while section content changes.
    private var rootContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CLSpacing.xl) {
                CommunitySearchField(
                    query: $viewModel.searchQuery,
                    isFocused: $isSearchFocused
                )

                if !viewModel.availableInterestTags.isEmpty {
                    CommunityCategoryChips(
                        interestTags: viewModel.availableInterestTags,
                        selectedInterestTag: $viewModel.selectedInterestTag
                    )
                }

                Group {
                    switch viewModel.state {
                    case .idle, .loading:
                        loadingSections
                    case .empty:
                        emptyState
                    case .error:
                        errorState
                    case .loaded:
                        loadedSections
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, CLSpacing.sm)
            .clAppear()
        }
    }

    @ViewBuilder private var loadedSections: some View {
        if viewModel.filteredCommunities.isEmpty {
            filterEmptyState
        } else if hasActiveFilters {
            resultsSection
        } else {
            VStack(alignment: .leading, spacing: CLSpacing.xl) {
                popularSection
                newCommunitiesSection
            }
        }
    }

    private var loadingSections: some View {
        ProgressView("Loading communities…")
            .font(CLTypography.callout)
            .foregroundStyle(CLColor.inkMuted)
            .tint(CLColor.primary)
            .padding(.vertical, CLSpacing.xxl)
            .accessibilityLabel("Loading communities")
    }

    private var hasActiveFilters: Bool {
        !viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || viewModel.selectedInterestTag != nil
    }

    private var popularSection: some View {
        VStack(alignment: .leading, spacing: CLSpacing.md) {
            CommunitySectionHeader(
                title: "Popular communities",
                onSeeAll: {
                    navigate(to: .allCommunities(sortOrder: .popular))
                }
            )

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: CLSpacing.md) {
                    ForEach(popularItems) { community in
                        Button {
                            navigate(to: detailRoute(for: community))
                        } label: {
                            PopularCommunityCard(
                                community: community,
                                viewportWidth: carouselViewportWidth,
                                coordinateSpace: carouselCoordinateSpace
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(CommunityContentPolicy.safeDisplayName(community.name))
                        .accessibilityValue(
                            CommunityMetadataPresentation.make(for: community).accessibilityText
                        )
                        .accessibilityHint("Opens community details")
                    }
                }
                .padding(.horizontal, CLSpacing.screenHorizontal)
            }
            .coordinateSpace(name: carouselCoordinateSpace)
            .background {
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: CarouselViewportWidthPreferenceKey.self,
                        value: geometry.size.width
                    )
                }
            }
            .onPreferenceChange(CarouselViewportWidthPreferenceKey.self) {
                carouselViewportWidth = $0
            }
        }
    }

    private var popularItems: [Community] {
        Array(viewModel.suggestedCommunities.prefix(4))
    }

    private var newCommunitiesSection: some View {
        VStack(alignment: .leading, spacing: CLSpacing.md) {
            CommunitySectionHeader(
                title: "New communities",
                onSeeAll: {
                    navigate(to: .allCommunities(sortOrder: .newest))
                }
            )

            CommunityRows(
                communities: Array(viewModel.newCommunities.prefix(5)),
                onSelect: { community in
                    navigate(to: detailRoute(for: community))
                }
            )
        }
    }

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: CLSpacing.md) {
            CommunitySectionHeader(title: resultsTitle)
            CommunityRows(
                communities: viewModel.sortedCommunities,
                onSelect: { community in
                    navigate(to: detailRoute(for: community))
                }
            )
        }
    }

    private var resultsTitle: String {
        if !viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Results"
        }
        if let category = viewModel.selectedInterestTag {
            return "Explore \(category)"
        }
        return "Results"
    }

    private var filterEmptyState: some View {
        CLEmptyState(
            systemImage: "magnifyingglass",
            title: "No communities found",
            message: "Try another search or category.",
            actionTitle: "Clear filters",
            actionAccessibilityLabel: "Clear search and category filters"
        ) {
            viewModel.clearFilters()
        }
    }

    private var emptyState: some View {
        CLEmptyState(
            systemImage: "person.3",
            title: "No communities yet",
            message: "Create the first community and bring people together.",
            actionTitle: "Create community",
            actionAccessibilityLabel: "Create community"
        ) {
            showCreateSheet = true
        }
    }

    private var errorState: some View {
        CLEmptyState(
            systemImage: "exclamationmark.triangle",
            title: "Couldn’t load communities",
            message: "Check your connection and try again.",
            actionTitle: "Try again",
            actionAccessibilityLabel: "Try loading communities again",
            titleAccessibilityLabel: "Couldn’t load communities"
        ) {
            Task { await viewModel.loadCommunities() }
        }
    }

    private func navigate(to route: CommunitiesRoute) {
        navigationPath = CommunitiesNavigationPathPolicy.appending(route, to: navigationPath)
    }

    private func detailRoute(for community: Community) -> CommunitiesRoute {
        .communityDetail(
            id: community.id,
            name: CommunityContentPolicy.safeDisplayName(community.name)
        )
    }
}

private struct AllCommunitiesView: View {
    let communities: [Community]
    let onCommunitySelected: (Community) -> Void
    @State private var searchQuery = ""
    @State private var selectedInterestTag: String?
    @State private var sortOrder: CommunitySortOrder
    @FocusState private var isSearchFocused: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(
        communities: [Community],
        initialSortOrder: CommunitySortOrder,
        onCommunitySelected: @escaping (Community) -> Void
    ) {
        self.communities = communities
        self.onCommunitySelected = onCommunitySelected
        _selectedInterestTag = State(initialValue: nil)
        _sortOrder = State(initialValue: initialSortOrder)
    }

    private var availableInterestTags: [String] {
        Array(
            Set(
                communities
                    .map(\.interestTag)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            )
        )
        .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private var filteredCommunities: [Community] {
        let filtered = CommunitiesViewModel.filter(
            communities,
            searchQuery: searchQuery,
            selectedInterestTag: selectedInterestTag
        )
        return CommunitiesViewModel.sort(filtered, by: sortOrder)
    }

    private var hasActiveFilters: Bool {
        !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || selectedInterestTag != nil
    }

    private var resultCountText: String {
        let count = filteredCommunities.count
        return count == 1 ? "1 community" : "\(count) communities"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CLSpacing.lg) {
                CommunitySearchField(
                    query: $searchQuery,
                    isFocused: $isSearchFocused
                )

                CommunityCategoryChips(
                    interestTags: availableInterestTags,
                    selectedInterestTag: $selectedInterestTag
                )

                catalogControls

                if filteredCommunities.isEmpty {
                    catalogEmptyState
                } else {
                    CommunityRows(
                        communities: filteredCommunities,
                        onSelect: onCommunitySelected
                    )
                }
            }
            .padding(.vertical, CLSpacing.md)
        }
        .clCanvasBackground()
        .navigationTitle("All Communities")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder private var catalogEmptyState: some View {
        if hasActiveFilters {
            CLEmptyState(
                systemImage: "magnifyingglass",
                title: "No communities found",
                message: "Try another search or category.",
                actionTitle: "Clear filters",
                actionAccessibilityLabel: "Clear search and category filters",
                action: clearFilters
            )
        } else {
            CLEmptyState(
                systemImage: "magnifyingglass",
                title: "No communities found",
                message: "Try another search or category."
            )
        }
    }

    @ViewBuilder private var catalogControls: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: CLSpacing.xs) {
                Text(resultCountText)
                HStack(spacing: CLSpacing.md) {
                    clearFiltersButton
                    Spacer(minLength: CLSpacing.xs)
                    sortMenu
                }
            }
            .catalogControlsStyle()
        } else {
            HStack(spacing: CLSpacing.md) {
                Text(resultCountText)
                Spacer(minLength: CLSpacing.xs)
                clearFiltersButton
                sortMenu
            }
            .catalogControlsStyle()
        }
    }

    @ViewBuilder private var clearFiltersButton: some View {
        if hasActiveFilters {
            Button("Clear filters", action: clearFilters)
                .font(CLTypography.callout.weight(.medium))
                .foregroundStyle(CLColor.primary)
                .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
                .accessibilityLabel("Clear search and category filters")
        }
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sort communities", selection: $sortOrder) {
                ForEach(CommunitySortOrder.allCases, id: \.self) { order in
                    Text(order.rawValue).tag(order)
                }
            }
        } label: {
            Label(sortOrder.rawValue, systemImage: "arrow.up.arrow.down")
                .font(CLTypography.callout.weight(.medium))
                .foregroundStyle(CLColor.primary)
                .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
        }
        .accessibilityLabel("Sort communities")
        .accessibilityValue(sortOrder.rawValue)
    }

    private func clearFilters() {
        searchQuery = ""
        selectedInterestTag = nil
    }
}

private extension View {
    func catalogControlsStyle() -> some View {
        font(CLTypography.callout)
            .foregroundStyle(CLColor.inkSecondary)
            .padding(.horizontal, CLSpacing.screenHorizontal)
    }
}

// MARK: - Card

private struct PopularCommunityCard: View {
    let community: Community
    let viewportWidth: CGFloat
    let coordinateSpace: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var horizontalMidpoint: CGFloat = 0

    private let width: CGFloat = 260

    private var edgeProgress: CGFloat {
        let distance = abs(horizontalMidpoint - viewportWidth / 2)
        return min(max(distance / max(viewportWidth / 2, 1), 0), 1)
    }

    private var scale: CGFloat {
        reduceMotion ? 1 : 1 - (0.04 * edgeProgress)
    }

    private var opacity: Double {
        reduceMotion ? 1 : 1 - (0.12 * edgeProgress)
    }

    private var memberCountText: String {
        let normalizedCount = max(0, community.memberCount)
        let count = normalizedCount.formatted(.number.notation(.compactName))
        return normalizedCount == 1 ? "\(count) member" : "\(count) members"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CLSpacing.sm) {
            CommunityArtworkView(community: community, cornerRadius: CLRadius.xl)
                .frame(width: width - (CLSpacing.sm * 2))
                .aspectRatio(4 / 3, contentMode: .fit)

            VStack(alignment: .leading, spacing: CLSpacing.xxs) {
                Text(CommunityContentPolicy.safeDisplayName(community.name))
                    .font(CLTypography.headline)
                    .foregroundStyle(CLColor.ink)

                Text(community.interestTag)
                    .font(CLTypography.subheadline)
                    .foregroundStyle(CLColor.inkSecondary)

                Text(memberCountText)
                    .font(CLTypography.footnote)
                    .foregroundStyle(CLColor.inkMuted)
            }
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(CLSpacing.sm)
        .frame(width: width)
        .background(CLColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: CLRadius.xl, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: CLRadius.xl, style: .continuous)
                .stroke(CLColor.hairline, lineWidth: 1)
        }
        .background {
            GeometryReader { geometry in
                Color.clear.preference(
                    key: PopularCardMidpointPreferenceKey.self,
                    value: geometry.frame(in: .named(coordinateSpace)).midX
                )
            }
        }
        .onPreferenceChange(PopularCardMidpointPreferenceKey.self) { horizontalMidpoint = $0 }
        .scaleEffect(scale)
        .opacity(opacity)
        .accessibilityElement(children: .ignore)
    }
}

private struct PopularCardMidpointPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct CarouselViewportWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct CommunityRowView: View {
    let community: Community
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(spacing: CLSpacing.md) {
            CommunityArtworkView(community: community, cornerRadius: CLRadius.sm)
                .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: CLSpacing.xxs) {
                Text(CommunityContentPolicy.safeDisplayName(community.name))
                    .font(CLTypography.headline)
                    .foregroundStyle(CLColor.ink)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : 2)
                    .fixedSize(horizontal: false, vertical: true)
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
