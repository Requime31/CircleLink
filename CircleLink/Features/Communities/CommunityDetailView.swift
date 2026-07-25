import SwiftUI

struct CommunityDetailView: View {
    @ObservedObject var viewModel: CommunityDetailViewModel
    /// Called with `(chatId, title)` after group chat is created or opened.
    let onOpenGroupChat: (String, String) -> Void

    var body: some View {
        Group {
            switch viewModel.communityState {
            case .idle, .loading:
                ProgressView("Loading community…")
                    .tint(CLColor.primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case let .error(message):
                errorState(message: message)
            case .empty:
                errorState(message: "Community not found.")
            case let .loaded(community):
                detailContent(community: community)
            }
        }
        .background(CLColor.canvas)
        .navigationTitle(viewModel.communityState.loadedValue?.name ?? "Community")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
        }
    }

    @ViewBuilder
    private func detailContent(community: Community) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CLSpacing.lg) {
                headerSection(community: community)
                membershipSection
                membersSection
            }
            .padding(CLSpacing.lg)
        }
    }

    @ViewBuilder
    private func headerSection(community: Community) -> some View {
        VStack(alignment: .leading, spacing: CLSpacing.md) {
            Text(community.interestTag)
                .font(CLTypography.callout)
                .foregroundStyle(CLColor.ink)
                .padding(.horizontal, CLSpacing.md)
                .padding(.vertical, CLSpacing.sm)
                .background(CLColor.surfaceSoft)
                .clipShape(Capsule())

            Text(community.description)
                .font(CLTypography.body)
                .foregroundStyle(CLColor.muted)

            Text(memberCountLabel(for: community.memberCount))
                .font(CLTypography.caption)
                .foregroundStyle(CLColor.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var membershipSection: some View {
        VStack(spacing: CLSpacing.md) {
            if viewModel.isMember {
                Button {
                    Task { await viewModel.leave() }
                } label: {
                    membershipButtonLabel(title: "Leave Community", isLoading: viewModel.isMembershipActionInFlight)
                }
                .buttonStyle(.bordered)
                .tint(CLColor.ink)
                .disabled(viewModel.isMembershipActionInFlight)
                .accessibilityLabel("Leave community")

                Button {
                    Task {
                        if let result = await viewModel.openGroupChat() {
                            onOpenGroupChat(result.chatId, result.title)
                        }
                    }
                } label: {
                    Group {
                        if viewModel.isOpeningGroupChat {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
                        } else {
                            Text("Open Group Chat")
                                .font(CLTypography.button)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(CLColor.primary)
                .disabled(viewModel.isOpeningGroupChat || viewModel.isMembershipActionInFlight)
                .accessibilityLabel("Open group chat")
                .accessibilityHint("Opens the community group chat")
            } else {
                Button {
                    Task { await viewModel.join() }
                } label: {
                    membershipButtonLabel(title: "Join Community", isLoading: viewModel.isMembershipActionInFlight)
                }
                .buttonStyle(.borderedProminent)
                .tint(CLColor.primary)
                .disabled(viewModel.isMembershipActionInFlight)
                .accessibilityLabel("Join community")
            }

            if let membershipErrorMessage = viewModel.membershipErrorMessage {
                Text(membershipErrorMessage)
                    .font(CLTypography.caption)
                    .foregroundStyle(CLColor.error)
                    .multilineTextAlignment(.center)
                    .accessibilityLabel("Membership error: \(membershipErrorMessage)")
            }
        }
    }

    @ViewBuilder
    private var membersSection: some View {
        VStack(alignment: .leading, spacing: CLSpacing.md) {
            Text("Members")
                .font(CLTypography.section)
                .foregroundStyle(CLColor.ink)

            switch viewModel.membersState {
            case .idle, .loading:
                ProgressView("Loading members…")
                    .tint(CLColor.primary)
                    .frame(maxWidth: .infinity, alignment: .center)
            case .empty:
                CLEmptyState(
                    systemImage: "person.crop.circle.badge.questionmark",
                    title: "No members yet",
                    message: "Be the first to join this community."
                )
                .frame(maxHeight: 200)
            case let .error(message):
                CLEmptyState(
                    systemImage: "exclamationmark.triangle",
                    title: message,
                    actionTitle: "Retry",
                    actionAccessibilityLabel: "Retry loading members",
                    titleAccessibilityLabel: "Members error: \(message)"
                ) {
                    Task { await viewModel.load() }
                }
                .frame(maxHeight: 220)
            case let .loaded(members):
                LazyVStack(spacing: CLSpacing.md) {
                    ForEach(members) { member in
                        MemberRowView(user: member)
                    }
                }
            }
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
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
            } else {
                Text(title)
                    .font(CLTypography.button)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
            }
        }
    }

    private func memberCountLabel(for count: Int) -> String {
        count == 1 ? "1 member" : "\(count) members"
    }
}

private struct MemberRowView: View {
    let user: User

    var body: some View {
        HStack(spacing: CLSpacing.md) {
            AvatarImageView(
                localPreview: nil,
                avatarBase64: user.avatarBase64,
                avatarURL: user.avatarURL,
                size: 44
            )

            Text(user.displayName)
                .font(CLTypography.callout)
                .foregroundStyle(CLColor.ink)

            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Member: \(user.displayName)")
    }
}

private extension ViewState {
    var loadedValue: T? {
        if case let .loaded(value) = self {
            return value
        }
        return nil
    }
}
