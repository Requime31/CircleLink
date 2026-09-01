import SwiftUI

struct CommunityDetailView: View {
    @ObservedObject var viewModel: CommunityDetailViewModel
    /// Name from the list — used until `load()` finishes, so the nav title does not flash "Community".
    let initialTitle: String
    let onOpenGroupChat: (String, String) -> Void
    let makePeerProfileSheet: (String, PeerProfileMode) -> PeerProfileSheet

    @State private var presentedPeer: PeerSheetItem?
    @State private var selectedTab: CommunityDetailTab = .feed
    @State private var showLeaveConfirmation = false
    @State private var composeMode: CommunityPost?
    @State private var isCreatingPost = false
    @State private var showsCommunityEditor = false
    @State private var presentedMedia: IdentifiedURL?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            switch viewModel.communityState {
            case .idle, .loading:
                CLLoadingState(message: "Loading community…")
            case let .error(message):
                errorState(message: message)
            case .empty:
                errorState(message: "Community not found.")
            case let .loaded(community):
                detailContent(community: community)
            }
        }
        .clCanvasBackground()
        .navigationTitle(
            CommunityContentPolicy.safeDisplayName(
                viewModel.communityState.loadedValue?.name ?? initialTitle
            )
        )
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(CLColor.canvas.opacity(0.92), for: .navigationBar)
        .toolbar {
            if viewModel.canEditCover {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showsCommunityEditor = true
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("Edit community")
                }
            }
        }
        .sheet(item: $presentedPeer) { peer in
            makePeerProfileSheet(peer.userId, .social)
        }
        .task { await viewModel.load() }
        .sheet(isPresented: $showsCommunityEditor) {
            if let community = viewModel.communityState.loadedValue {
                EditCommunitySheet(viewModel: viewModel, community: community) {
                    showsCommunityEditor = false
                }
            }
        }
        .sheet(isPresented: $isCreatingPost) {
            CommunityComposePostSheet(viewModel: viewModel, post: nil) { isCreatingPost = false }
        }
        .sheet(item: $composeMode) { post in
            CommunityComposePostSheet(viewModel: viewModel, post: post) { composeMode = nil }
        }
        .alert(
            "Leave this community?",
            isPresented: $showLeaveConfirmation,
        ) {
            Button("Leave Community", role: .destructive) {
                Task { await viewModel.leave() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You’ll lose access to the group chat until you join again.")
        }
        .fullScreenCover(item: $presentedMedia) { item in
            ChatMediaFullscreenView(url: item.url)
        }
    }

    private func detailContent(community: Community) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                CommunityArtworkView(community: community, cornerRadius: 0)
                    .frame(height: 280)

                VStack(alignment: .leading, spacing: CLSpacing.lg) {
                    headerSection(community: community)
                    aboutSection(community: community)
                    groupChatButton
                    membershipError
                }
                .padding(.horizontal, CLSpacing.screenHorizontal)
                .padding(.vertical, CLSpacing.lg)

                tabs
                tabContent
                    .padding(.horizontal, CLSpacing.screenHorizontal)
                    .padding(.top, CLSpacing.lg)
                    .padding(.bottom, CLSpacing.xxl)
            }
            .clAppear()
        }
    }

    private func headerSection(community: Community) -> some View {
        VStack(alignment: .leading, spacing: CLSpacing.xs) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: CLSpacing.md) {
                    communityName(community.name)
                    membershipButton
                }
            } else {
                HStack(alignment: .top, spacing: CLSpacing.md) {
                    communityName(community.name)
                    membershipButton
                }
            }

            Text(memberCountLabel(for: community.memberCount))
                .font(CLTypography.callout)
                .foregroundStyle(CLColor.inkSecondary)
        }
    }

    @ViewBuilder
    private var membershipButton: some View {
        Button {
            if viewModel.isMember {
                showLeaveConfirmation = true
            } else {
                Task { await viewModel.join() }
            }
        } label: {
            membershipButtonLabel(
                title: viewModel.isMember ? "Joined" : "Join",
                isLoading: viewModel.isMembershipActionInFlight
            )
            .id(viewModel.isMembershipActionInFlight ? "loading" : viewModel.isMember ? "joined" : "join")
            .transition(.opacity.combined(with: .scale(scale: 0.92)))
        }
        .buttonStyle(CLPrimaryButtonStyle())
        .frame(width: 112, height: AccessibilityHelpers.minimumTouchTarget)
        .disabled(viewModel.isMembershipActionInFlight)
        .animation(CLMotion.soft, value: viewModel.isMember)
        .animation(CLMotion.micro, value: viewModel.isMembershipActionInFlight)
        .accessibilityLabel(
            viewModel.isMember
                ? "Joined. Double tap to leave community"
                : "Join community"
        )
    }

    private func aboutSection(community: Community) -> some View {
        CommunityDescriptionSection(
            communityName: community.name,
            description: community.description
        )
    }

    private var groupChatButton: some View {
        Button {
            Task {
                if let result = await viewModel.openGroupChat() {
                    onOpenGroupChat(result.chatId, result.title)
                }
            }
        } label: {
            HStack(spacing: CLSpacing.sm) {
                Image(systemName: "message")
                membershipButtonLabel(title: "Open Group Chat", isLoading: viewModel.isOpeningGroupChat)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(CLSecondaryButtonStyle())
        .disabled(!viewModel.isMember || viewModel.isOpeningGroupChat || viewModel.isMembershipActionInFlight)
        .accessibilityLabel(viewModel.isMember ? "Open group chat" : "Join this community to open group chat")
    }

    @ViewBuilder
    private var membershipError: some View {
        if let message = viewModel.membershipErrorMessage {
            Text(message)
                .font(CLTypography.footnote)
                .foregroundStyle(CLColor.error)
                .padding(CLSpacing.sm)
                .frame(maxWidth: .infinity)
                .background(CLColor.errorSoft)
                .clipShape(RoundedRectangle(cornerRadius: CLRadius.sm, style: .continuous))
                .accessibilityLabel("Membership error: \(message)")
        }
    }

    private var tabs: some View {
        HStack(spacing: 0) {
            ForEach(CommunityDetailTab.allCases) { tab in
                Button {
                    withAnimation(CLMotion.soft) { selectedTab = tab }
                } label: {
                    VStack(spacing: CLSpacing.sm) {
                        Text(tab.title)
                            .font(CLTypography.callout.weight(.medium))
                            .foregroundStyle(selectedTab == tab ? CLColor.primary : CLColor.inkSecondary)
                        Rectangle()
                            .fill(selectedTab == tab ? CLColor.primary : Color.clear)
                            .frame(height: 2)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(CLColor.hairline).frame(height: 1)
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .feed:
            feedContent
        case .members:
            membersSection
        case .gallery:
            galleryContent
        case .events:
            placeholderTab(
                systemImage: "calendar",
                title: "No events yet",
                message: "Upcoming community events will appear here."
            )
        }
    }

    private var feedContent: some View {
        VStack(spacing: CLSpacing.md) {
            if viewModel.isMember {
                Button { isCreatingPost = true } label: {
                    Label("Write a post", systemImage: "square.and.pencil")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(CLPrimaryButtonStyle())
            }

            if let message = viewModel.postErrorMessage {
                Text(message).font(CLTypography.footnote).foregroundStyle(CLColor.error)
            }

            switch viewModel.postsState {
            case .idle, .loading:
                ProgressView("Loading posts…")
                    .tint(CLColor.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, CLSpacing.lg)
            case .empty:
                placeholderTab(systemImage: "text.bubble", title: "No community posts yet", message: "Be the first to start the conversation.")
            case let .error(message):
                postsErrorState(message: message)
            case let .loaded(posts):
                ForEach(posts) { post in
                    CommunityPostCard(
                        post: post,
                        author: viewModel.author(for: post),
                        canManage: viewModel.canManage(post),
                        currentUserId: viewModel.currentUserId,
                        onSelectAuthor: { userId in
                            presentedPeer = PeerSheetItem(userId: userId)
                        },
                        onSelectMedia: { url in
                            presentedMedia = IdentifiedURL(url)
                        },
                        onEdit: { composeMode = post },
                        onDelete: { Task { await viewModel.deletePost(post) } }
                    )
                }
            }
        }
    }

    private var galleryContent: some View {
        Group {
            switch viewModel.postsState {
            case .idle, .loading:
                ProgressView("Loading photos…")
                    .tint(CLColor.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, CLSpacing.lg)
            case .empty:
                placeholderTab(systemImage: "photo.on.rectangle.angled", title: "No photos yet", message: "Photos from community posts will appear here.")
            case let .error(message):
                postsErrorState(message: message)
            case let .loaded(posts):
                let imagePosts = posts.filter { $0.imageURL != nil }
                if imagePosts.isEmpty {
                    placeholderTab(systemImage: "photo.on.rectangle.angled", title: "No photos yet", message: "Photos from community posts will appear here.")
                } else {
                    LazyVGrid(columns: galleryColumns, spacing: CLSpacing.sm) {
                        ForEach(imagePosts) { post in
                            if let imageURL = post.imageURL {
                                Button {
                                    presentedMedia = IdentifiedURL(imageURL)
                                } label: {
                                    CommunityGalleryThumbnail(url: imageURL)
                                }
                                .buttonStyle(.plain)
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel(galleryAccessibilityLabel(for: post))
                            }
                        }
                    }
                }
            }
        }
    }

    private func postsErrorState(message: String) -> some View {
        CLEmptyState(
            systemImage: "exclamationmark.triangle",
            title: "Couldn’t load posts",
            message: message,
            actionTitle: "Retry",
            actionAccessibilityLabel: "Retry loading community posts"
        ) {
            Task { await viewModel.reloadPosts() }
        }
    }

    private func placeholderTab(systemImage: String, title: String, message: String) -> some View {
        CLEmptyState(systemImage: systemImage, title: title, message: message)
            .frame(maxWidth: .infinity)
    }

    private var membersSection: some View {
        VStack(alignment: .leading, spacing: CLSpacing.sm) {
            switch viewModel.membersState {
            case .idle, .loading:
                ProgressView("Loading members…")
                    .tint(CLColor.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, CLSpacing.lg)
            case .empty:
                placeholderTab(systemImage: "person.3", title: "No members yet", message: "Join to be the first member.")
            case let .error(message):
                CLEmptyState(
                    systemImage: "exclamationmark.triangle",
                    title: message,
                    actionTitle: "Retry",
                    actionAccessibilityLabel: "Retry loading members"
                ) {
                    Task { await viewModel.load() }
                }
            case let .loaded(members):
                LazyVStack(spacing: 0) {
                    ForEach(members) { member in
                        memberRow(for: member)
                        if member.id != members.last?.id {
                            Rectangle()
                                .fill(CLColor.hairline)
                                .frame(height: 1)
                                .padding(.leading, MemberRowView.avatarSize + CLSpacing.sm)
                                .accessibilityHidden(true)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func memberRow(for member: User) -> some View {
        let isSelf = member.id == viewModel.currentUserId
        let displayName = member.displayName.isEmpty ? "Member" : member.displayName

        if isSelf {
            MemberRowView(user: member, showsChevron: false)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("You, \(displayName)")
        } else {
            Button { presentedPeer = PeerSheetItem(userId: member.id) } label: {
                MemberRowView(user: member, showsChevron: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("View profile for \(displayName)")
            .accessibilityHint("Opens member profile")
        }
    }

    private func errorState(message: String) -> some View {
        CLEmptyState(
            systemImage: "exclamationmark.triangle",
            title: message,
            actionTitle: "Retry",
            actionAccessibilityLabel: "Retry loading community",
            titleAccessibilityLabel: "Error: \(message)"
        ) {
            Task { await viewModel.load() }
        }
    }

    @ViewBuilder
    private func membershipButtonLabel(title: String, isLoading: Bool) -> some View {
        if isLoading {
            ProgressView().tint(CLColor.onPrimary)
        } else {
            Text(title)
        }
    }

    private func memberCountLabel(for count: Int) -> String {
        count == 1 ? "1 member" : "\(count) members"
    }

    private func communityName(_ name: String) -> some View {
        let normalizedName = CommunityContentPolicy.trimmed(name)
        let displayName = normalizedName.isEmpty ? "Community" : normalizedName

        return Text(displayName)
            .font(CLTypography.title)
            .foregroundStyle(CLColor.ink)
            .lineLimit(3)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)
            .accessibilityAddTraits(.isHeader)
    }

    private var galleryColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: CLSpacing.sm),
            GridItem(.flexible(), spacing: CLSpacing.sm)
        ]
    }

    private func galleryAccessibilityLabel(for post: CommunityPost) -> String {
        let authorName = viewModel.author(for: post)?.displayName
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = authorName.flatMap { $0.isEmpty ? nil : $0 } ?? "Member"
        let relativeDate = post.createdAt.formatted(.relative(presentation: .named))
        return "Photo by \(displayName), \(relativeDate)"
    }
}

private struct CommunityDescriptionSection: View {
    let communityName: String
    let description: String

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var compactHeight: CGFloat = 0
    @State private var fullHeight: CGFloat = 0
    @State private var showsFullDescription = false

    private var text: String {
        CommunityContentPolicy.displayDescription(description)
    }

    private var compactLineLimit: Int {
        dynamicTypeSize.isAccessibilitySize ? 5 : 3
    }

    private var isTruncated: Bool {
        fullHeight > compactHeight + 1
    }

    var body: some View {
        Group {
            if text.isEmpty {
                EmptyView()
            } else {
                VStack(alignment: .leading, spacing: CLSpacing.xs) {
                    Text(text)
                        .font(CLTypography.body)
                        .foregroundStyle(CLColor.inkSecondary)
                        .lineLimit(showsFullDescription ? nil : compactLineLimit)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(compactHeightReader)
                        .background(fullHeightReader)

                    if isTruncated || showsFullDescription {
                        Button(showsFullDescription ? "Hide" : "More") {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showsFullDescription.toggle()
                            }
                        }
                        .font(CLTypography.callout.weight(.medium))
                        .foregroundStyle(CLColor.primary)
                        .accessibilityLabel(
                            showsFullDescription
                                ? "Hide full community description"
                                : "Read full community description"
                        )
                    }
                }
            }
        }
        .onPreferenceChange(CompactDescriptionHeightKey.self) { newValue in
            if abs(compactHeight - newValue) > 0.5 { compactHeight = newValue }
        }
        .onPreferenceChange(FullDescriptionHeightKey.self) { newValue in
            if abs(fullHeight - newValue) > 0.5 { fullHeight = newValue }
        }
    }

    private var compactHeightReader: some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: CompactDescriptionHeightKey.self,
                value: proxy.size.height
            )
        }
    }

    private var fullHeightReader: some View {
        Text(text)
            .font(CLTypography.body)
            .fixedSize(horizontal: false, vertical: true)
            .hidden()
            .accessibilityHidden(true)
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: FullDescriptionHeightKey.self,
                        value: proxy.size.height
                    )
                }
            }
    }
}

private struct CompactDescriptionHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct FullDescriptionHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct CommunityGalleryThumbnail: View {
    let url: URL

    var body: some View {
        GeometryReader { proxy in
            AsyncImage(url: url) { phase in
                switch phase {
                case let .success(image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    placeholder(systemImage: "photo.badge.exclamationmark")
                case .empty:
                    placeholder()
                @unknown default:
                    placeholder()
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.width)
            .clipped()
        }
        .aspectRatio(1, contentMode: .fit)
        .background(CLColor.surfaceSoft)
        .clipShape(RoundedRectangle(cornerRadius: CLRadius.sm, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: CLRadius.sm, style: .continuous)
                .stroke(CLColor.hairline, lineWidth: 1)
        }
    }

    private func placeholder(systemImage: String? = nil) -> some View {
        ZStack {
            CLColor.surfaceSoft
            if let systemImage {
                Image(systemName: systemImage)
                    .foregroundStyle(CLColor.inkMuted)
            } else {
                ProgressView()
                    .tint(CLColor.primary)
            }
        }
        .accessibilityHidden(true)
    }
}

private enum CommunityDetailTab: String, CaseIterable, Identifiable {
    case feed
    case members
    case gallery
    case events

    var id: Self { self }
    var title: String { rawValue.capitalized }
}

private struct MemberRowView: View {
    static let avatarSize: CGFloat = 44

    let user: User
    var showsChevron = true

    var body: some View {
        HStack(spacing: CLSpacing.sm) {
            AvatarImageView(
                localPreview: nil,
                avatarBase64: user.avatarBase64,
                avatarURL: user.avatarURL,
                size: Self.avatarSize
            )

            Text(user.displayName.isEmpty ? "Member" : user.displayName)
                .font(CLTypography.headline)
                .foregroundStyle(CLColor.ink)
                .frame(maxWidth: .infinity, alignment: .leading)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CLColor.inkMuted)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, CLSpacing.sm)
        .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
        .contentShape(Rectangle())
    }
}

private struct PeerSheetItem: Identifiable {
    let userId: String
    var id: String { userId }
}

private extension ViewState {
    var loadedValue: T? {
        if case let .loaded(value) = self { return value }
        return nil
    }
}
