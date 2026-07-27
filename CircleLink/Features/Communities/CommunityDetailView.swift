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
                    .foregroundStyle(CLColor.inkMuted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            .padding(.horizontal, CLSpacing.md)
            .padding(.vertical, CLSpacing.lg)
            .clAppear()
        }
    }

    @ViewBuilder
    private func headerSection(community: Community) -> some View {
        VStack(alignment: .leading, spacing: CLSpacing.sm) {
            Text(community.interestTag)
                .font(CLTypography.caption)
                .foregroundStyle(CLColor.ink)
                .padding(.horizontal, CLSpacing.sm)
                .padding(.vertical, CLSpacing.xxs)
                .background(CLColor.primarySoft)
                .clipShape(Capsule())

            Text(community.description)
                .font(CLTypography.body)
                .foregroundStyle(CLColor.inkSecondary)

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
    private var membersSection: some View {
        VStack(alignment: .leading, spacing: CLSpacing.sm) {
            Text("Members")
                .font(CLTypography.headline)
                .foregroundStyle(CLColor.ink)

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
            case let .error(message):
                Text(message)
                    .font(CLTypography.subheadline)
                    .foregroundStyle(CLColor.inkSecondary)
                    .accessibilityLabel("Members error: \(message)")
            case let .loaded(members):
                LazyVStack(spacing: 0) {
                    ForEach(members) { member in
                        MemberRowView(user: member)
                        if member.id != members.last?.id {
                            Rectangle()
                                .fill(CLColor.hairline)
                                .frame(height: 1)
                                .padding(.leading, MemberRowView.avatarSize + CLSpacing.sm)
                        }
                    }
                }
            }
        }
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
            Button("Retry") {
                Task { await viewModel.load() }
            }
            .buttonStyle(CLSecondaryButtonStyle())
            .padding(.top, CLSpacing.xs)
            .accessibilityLabel("Retry loading community")
        }
        .padding(CLSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

private struct MemberRowView: View {
    static let avatarSize: CGFloat = 44

    let user: User

    var body: some View {
        HStack(spacing: CLSpacing.sm) {
            AvatarImageView(
                localPreview: nil,
                avatarBase64: user.avatarBase64,
                avatarURL: user.avatarURL,
                size: Self.avatarSize
            )

            Text(user.displayName)
                .font(CLTypography.headline)
                .foregroundStyle(CLColor.ink)

            Spacer()
        }
        .padding(.vertical, CLSpacing.sm)
        .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
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
