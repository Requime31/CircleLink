import PhotosUI
import SwiftUI

struct CommunityDetailView: View {
    @ObservedObject var viewModel: CommunityDetailViewModel
    let onOpenGroupChat: (String, String) -> Void
    let makePeerProfileSheet: (String, PeerProfileMode) -> PeerProfileSheet

    @State private var presentedPeer: PeerSheetItem?
    @State private var selectedTab: CommunityDetailTab = .feed
    @State private var showLeaveConfirmation = false
    @State private var composeMode: CommunityPost?
    @State private var isCreatingPost = false
    @State private var selectedCover: PhotosPickerItem?

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
        .navigationTitle(viewModel.communityState.loadedValue?.name ?? "Community")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(CLColor.canvas.opacity(0.92), for: .navigationBar)
        .toolbar {
            if viewModel.canEditCover {
                ToolbarItem(placement: .topBarTrailing) {
                    PhotosPicker(selection: $selectedCover, matching: .images) {
                        Image(systemName: "photo")
                    }
                    .accessibilityLabel("Change community cover")
                }
            }
        }
        .sheet(item: $presentedPeer) { peer in
            makePeerProfileSheet(peer.userId, .social)
        }
        .task { await viewModel.load() }
        .onChange(of: selectedCover) { item in
            Task {
                guard let item, let data = try? await item.loadTransferable(type: Data.self) else { return }
                await viewModel.updateCover(image: data)
                selectedCover = nil
            }
        }
        .sheet(isPresented: $isCreatingPost) {
            CommunityComposePostSheet(viewModel: viewModel, post: nil) { isCreatingPost = false }
        }
        .sheet(item: $composeMode) { post in
            CommunityComposePostSheet(viewModel: viewModel, post: post) { composeMode = nil }
        }
        .confirmationDialog(
            "Leave this community?",
            isPresented: $showLeaveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Leave Community", role: .destructive) {
                Task { await viewModel.leave() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You’ll lose access to the group chat until you join again.")
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
            HStack(alignment: .center, spacing: CLSpacing.md) {
                Text(community.name)
                    .font(CLTypography.title)
                    .foregroundStyle(CLColor.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)

                membershipButton
            }

            Text(memberCountLabel(for: community.memberCount))
                .font(CLTypography.callout)
                .foregroundStyle(CLColor.inkSecondary)
        }
    }

    @ViewBuilder
    private var membershipButton: some View {
        if viewModel.isMember {
            Button { showLeaveConfirmation = true } label: {
                membershipButtonLabel(title: "Joined", isLoading: viewModel.isMembershipActionInFlight)
            }
            .buttonStyle(CLPrimaryButtonStyle())
            .frame(width: 112, height: AccessibilityHelpers.minimumTouchTarget)
            .disabled(viewModel.isMembershipActionInFlight)
            .accessibilityLabel("Joined. Double tap to leave community")
        } else {
            Button { Task { await viewModel.join() } } label: {
                membershipButtonLabel(title: "Join", isLoading: viewModel.isMembershipActionInFlight)
            }
            .buttonStyle(CLPrimaryButtonStyle())
            .frame(width: 112, height: AccessibilityHelpers.minimumTouchTarget)
            .disabled(viewModel.isMembershipActionInFlight)
            .accessibilityLabel("Join community")
        }
    }

    private func aboutSection(community: Community) -> some View {
        Text(community.description.isEmpty ? "No description yet." : community.description)
            .font(CLTypography.body)
            .foregroundStyle(community.description.isEmpty ? CLColor.inkMuted : CLColor.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
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

            if viewModel.posts.isEmpty {
                placeholderTab(systemImage: "text.bubble", title: "No community posts yet", message: "Be the first to start the conversation.")
            } else {
                ForEach(viewModel.posts) { post in
                    CommunityPostCard(
                        post: post,
                        author: viewModel.author(for: post),
                        canManage: viewModel.canManage(post),
                        onEdit: { composeMode = post },
                        onDelete: { Task { await viewModel.deletePost(post) } }
                    )
                }
            }
        }
    }

    private var galleryContent: some View {
        let imagePosts = viewModel.posts.filter { $0.imageURL != nil }
        return Group {
            if imagePosts.isEmpty {
                placeholderTab(systemImage: "photo.on.rectangle.angled", title: "No photos yet", message: "Photos from community posts will appear here.")
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: CLSpacing.sm) {
                    ForEach(imagePosts) { post in
                        CommunityPostImage(url: post.imageURL!)
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
            }
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
