import SwiftUI

struct CommunityDetailView: View {
    @ObservedObject var viewModel: CommunityDetailViewModel
    /// Called with `(chatId, title)` after group chat is created or opened.
    let onOpenGroupChat: (String, String) -> Void
    /// Builds Phase 2 peer profile sheet. Pass `communityId` so Connect works.
    let makePeerProfileSheet: (String, PeerProfileMode) -> PeerProfileSheet

    @State private var presentedPeer: PeerSheetItem?

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
        .sheet(item: $presentedPeer) { peer in
            makePeerProfileSheet(peer.userId, .social)
        }
        .task {
            await viewModel.load()
        }
    }

    // MARK: - Club hub

    @ViewBuilder
    private func detailContent(community: Community) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CLSpacing.xl) {
                headerSection(community: community)
                membershipSection
                aboutSection(community: community)
                membersSection
            }
            .padding(.horizontal, CLSpacing.screenHorizontal)
            .padding(.vertical, CLSpacing.lg)
            .clAppear()
        }
    }

    /// Name + interest + count — soft hub anchor (not a dashboard).
    @ViewBuilder
    private func headerSection(community: Community) -> some View {
        VStack(alignment: .leading, spacing: CLSpacing.sm) {
            Text(community.name)
                .font(CLTypography.title)
                .foregroundStyle(CLColor.ink)
                .accessibilityAddTraits(.isHeader)

            CLChip(
                title: community.interestTag,
                isEmphasized: true,
                accessibilityLabelText: "Interest: \(community.interestTag)"
            )

            Text(memberCountLabel(for: community.memberCount))
                .font(CLTypography.footnote)
                .foregroundStyle(CLColor.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var membershipSection: some View {
        VStack(spacing: CLSpacing.sm) {
            if viewModel.isMember {
                Button {
                    Task { await viewModel.leave() }
                } label: {
                    membershipButtonLabel(title: "Leave Community", isLoading: viewModel.isMembershipActionInFlight)
                }
                .buttonStyle(CLSecondaryButtonStyle())
                .disabled(viewModel.isMembershipActionInFlight)
                .accessibilityLabel("Leave community")

                Button {
                    Task {
                        if let result = await viewModel.openGroupChat() {
                            onOpenGroupChat(result.chatId, result.title)
                        }
                    }
                } label: {
                    membershipButtonLabel(title: "Open Group Chat", isLoading: viewModel.isOpeningGroupChat)
                }
                .buttonStyle(CLPrimaryButtonStyle())
                .disabled(viewModel.isOpeningGroupChat || viewModel.isMembershipActionInFlight)
                .accessibilityLabel("Open group chat")
                .accessibilityHint("Opens the community group chat")
            } else {
                Button {
                    Task { await viewModel.join() }
                } label: {
                    membershipButtonLabel(title: "Join Community", isLoading: viewModel.isMembershipActionInFlight)
                }
                .buttonStyle(CLPrimaryButtonStyle())
                .disabled(viewModel.isMembershipActionInFlight)
                .accessibilityLabel("Join community")
            }

            if let membershipErrorMessage = viewModel.membershipErrorMessage {
                Text(membershipErrorMessage)
                    .font(CLTypography.footnote)
                    .foregroundStyle(CLColor.error)
                    .padding(CLSpacing.sm)
                    .frame(maxWidth: .infinity)
                    .background(CLColor.errorSoft)
                    .clipShape(RoundedRectangle(cornerRadius: CLRadius.sm, style: .continuous))
                    .multilineTextAlignment(.center)
                    .accessibilityLabel("Membership error: \(membershipErrorMessage)")
            }
        }
    }

    @ViewBuilder
    private func aboutSection(community: Community) -> some View {
        VStack(alignment: .leading, spacing: CLSpacing.sm) {
            Text("About")
                .font(CLTypography.headline)
                .foregroundStyle(CLColor.ink)
                .accessibilityAddTraits(.isHeader)

            Text(community.description.isEmpty ? "No description yet." : community.description)
                .font(CLTypography.body)
                .foregroundStyle(community.description.isEmpty ? CLColor.inkMuted : CLColor.inkSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var membersSection: some View {
        VStack(alignment: .leading, spacing: CLSpacing.sm) {
            Text("Members")
                .font(CLTypography.headline)
                .foregroundStyle(CLColor.ink)
                .accessibilityAddTraits(.isHeader)

            switch viewModel.membersState {
            case .idle, .loading:
                ProgressView("Loading members…")
                    .tint(CLColor.primary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, CLSpacing.sm)
            case .empty:
                Text("No members yet.")
                    .font(CLTypography.subheadline)
                    .foregroundStyle(CLColor.inkMuted)
                    .padding(.vertical, CLSpacing.xs)
            case let .error(message):
                VStack(alignment: .leading, spacing: CLSpacing.sm) {
                    Text(message)
                        .font(CLTypography.subheadline)
                        .foregroundStyle(CLColor.inkSecondary)
                        .accessibilityLabel("Members error: \(message)")
                    Button("Retry") {
                        Task { await viewModel.load() }
                    }
                    .buttonStyle(CLSecondaryButtonStyle())
                    .accessibilityLabel("Retry loading members")
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

    /// Self stays visible but not a peer sheet (Connect would reject).
    @ViewBuilder
    private func memberRow(for member: User) -> some View {
        let isSelf = member.id == viewModel.currentUserId
        let displayName = member.displayName.isEmpty ? "Member" : member.displayName

        if isSelf {
            MemberRowView(user: member, showsChevron: false)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("You, \(displayName)")
        } else {
            Button {
                presentedPeer = PeerSheetItem(userId: member.id)
            } label: {
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
            ProgressView()
                .tint(CLColor.onPrimary)
        } else {
            Text(title)
        }
    }

    private func memberCountLabel(for count: Int) -> String {
        count == 1 ? "1 member" : "\(count) members"
    }
}

// MARK: - Member row

private struct MemberRowView: View {
    static let avatarSize: CGFloat = 44

    let user: User
    var showsChevron: Bool = true

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

/// Sheet identity for `.sheet(item:)`.
private struct PeerSheetItem: Identifiable {
    let userId: String
    var id: String { userId }
}

private extension ViewState {
    var loadedValue: T? {
        if case let .loaded(value) = self {
            return value
        }
        return nil
    }
}
