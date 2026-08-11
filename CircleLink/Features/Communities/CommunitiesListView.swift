import SwiftUI

struct CommunitiesListView: View {
    @ObservedObject var viewModel: CommunitiesViewModel
    let makeDetailViewModel: (String) -> CommunityDetailViewModel
    let makePeerProfileSheet: (String, PeerProfileMode) -> PeerProfileSheet
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
                    discoveryContent
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
        VStack(spacing: CLSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(CLColor.inkMuted)
                .padding(CLSpacing.md)
                .background(Circle().fill(CLColor.tintCream))
                .accessibilityHidden(true)
            Text("No communities match")
                .font(CLTypography.title2)
                .foregroundStyle(CLColor.ink)
            Text("Try a different search or clear the interest filter.")
                .font(CLTypography.subheadline)
                .foregroundStyle(CLColor.inkSecondary)
                .multilineTextAlignment(.center)
            Button("Clear filters") {
                viewModel.clearFilters()
            }
            .buttonStyle(CLSecondaryButtonStyle())
            .padding(.top, CLSpacing.xs)
            .accessibilityLabel("Clear search and interest filters")
        }
        .padding(CLSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

// MARK: - Filter chip

private struct InterestFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(CLTypography.subheadline)
                .foregroundStyle(isSelected ? CLColor.ink : CLColor.inkSecondary)
                .padding(.horizontal, CLSpacing.sm)
                .padding(.vertical, CLSpacing.xs)
                .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
                .background(isSelected ? CLColor.primarySoft : CLColor.surfaceSoft)
                .clipShape(Capsule(style: .continuous))
                .scaleEffect(isSelected && !reduceMotion ? 1.02 : 1)
        }
        .buttonStyle(.plain)
        .clSoftSpring(value: isSelected)
        .accessibilityLabel(title == "All" ? "All interests" : "\(title) interest")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint("Double tap to filter communities")
    }
}
