import SwiftUI

/// Community detail in Soft Orbit language. ViewModel bindings unchanged.
///
/// Data flow:
/// Appear → CommunityDetailViewModel.load → CommunityRepository / UserRepository
///   → community + members state → UI
/// Join / Leave / Open Group Chat → ViewModel → repos → membership / chat callbacks
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
                    .foregroundStyle(CLColor.muted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case let .error(message):
                errorState(message: message)
            case .empty:
                errorState(message: "This circle couldn't be found.")
            case let .loaded(community):
                detailContent(community: community)
            }
        }
        .background(CLColor.canvas.ignoresSafeArea())
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
                    .clAppear()
                membershipSection
                    .clAppear(delay: 0.06)
                membersSection
                    .clAppear(delay: 0.1)
            }
            .padding(CLSpacing.lg)
        }
    }

    @ViewBuilder
    private func headerSection(community: Community) -> some View {
        VStack(alignment: .leading, spacing: CLSpacing.md) {
            HStack(alignment: .center, spacing: CLSpacing.md) {
                ZStack {
                    Circle()
                        .fill(CLColor.companionSoft)
                        .frame(width: 56, height: 56)
                    Circle()
                        .stroke(CLColor.hairline, lineWidth: 1.5)
                        .frame(width: 34, height: 34)
                    Circle()
                        .fill(CLColor.primary.opacity(0.85))
                        .frame(width: 10, height: 10)
                        .offset(x: 12, y: -8)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: CLSpacing.xs) {
                    CLMetaPill(title: community.interestTag)
                        .accessibilityLabel("Interest: \(community.interestTag)")

                    HStack(spacing: CLSpacing.xs) {
                        Circle()
                            .fill(CLColor.companion)
                            .frame(width: 6, height: 6)
                            .accessibilityHidden(true)
                        Text(memberCountLabel(for: community.memberCount))
                            .font(CLTypography.caption)
                            .foregroundStyle(CLColor.mutedSoft)
                    }
                }
            }

            Text(community.description)
                .font(CLTypography.body)
                .foregroundStyle(CLColor.body)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(CLSpacing.base)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clCardStyle()
    }

    @ViewBuilder
    private var membershipSection: some View {
        VStack(spacing: CLSpacing.md) {
            if viewModel.isMember {
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
                                .tint(CLColor.onPrimary)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
                        } else {
                            Text("Open Group Chat")
                                .font(CLTypography.button)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
                        }
                    }
                    .foregroundStyle(CLColor.onPrimary)
                    .background(CLColor.primary)
                    .clipShape(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isOpeningGroupChat || viewModel.isMembershipActionInFlight)
                .accessibilityLabel("Open group chat")
                .accessibilityHint("Opens the community group chat")

                Button {
                    Task { await viewModel.leave() }
                } label: {
                    membershipButtonLabel(title: "Leave Community", isLoading: viewModel.isMembershipActionInFlight)
                        .font(CLTypography.buttonSmall)
                        .foregroundStyle(CLColor.ink)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
                        .background(CLColor.surfaceCard)
                        .clipShape(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous)
                                .strokeBorder(CLColor.hairline, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isMembershipActionInFlight)
                .accessibilityLabel("Leave community")
            } else {
                Button {
                    Task { await viewModel.join() }
                } label: {
                    membershipButtonLabel(title: "Join Community", isLoading: viewModel.isMembershipActionInFlight)
                        .font(CLTypography.button)
                        .foregroundStyle(CLColor.onPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
                        .background(CLColor.primary)
                        .clipShape(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isMembershipActionInFlight)
                .accessibilityLabel("Join community")
            }

            if let membershipErrorMessage = viewModel.membershipErrorMessage {
                Text(membershipErrorMessage)
                    .font(CLTypography.caption)
                    .foregroundStyle(CLColor.error)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
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
                .accessibilityAddTraits(.isHeader)

            switch viewModel.membersState {
            case .idle, .loading:
                ProgressView("Loading members…")
                    .tint(CLColor.primary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, CLSpacing.md)
            case .empty:
                membersEmpty
            case let .error(message):
                VStack(alignment: .leading, spacing: CLSpacing.sm) {
                    Text(message)
                        .font(CLTypography.callout)
                        .foregroundStyle(CLColor.muted)
                        .accessibilityLabel("Members error: \(message)")
                    Button("Retry") {
                        Task { await viewModel.load() }
                    }
                    .font(CLTypography.buttonSmall)
                    .foregroundStyle(CLColor.primary)
                    .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
                    .accessibilityLabel("Retry loading members")
                }
            case let .loaded(members):
                LazyVStack(spacing: CLSpacing.sm) {
                    ForEach(members) { member in
                        MemberRowView(user: member)
                    }
                }
            }
        }
        .padding(CLSpacing.base)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clCardStyle()
    }

    private var membersEmpty: some View {
        VStack(spacing: CLSpacing.sm) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.title2)
                .foregroundStyle(CLColor.muted)
                .padding(CLSpacing.md)
                .background(Circle().fill(CLColor.companionSoft))
                .accessibilityHidden(true)
            Text("No members yet")
                .font(CLTypography.bodyMedium)
                .foregroundStyle(CLColor.ink)
            Text("Be the first to join this orbit.")
                .font(CLTypography.callout)
                .foregroundStyle(CLColor.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, CLSpacing.sm)
    }

    private func errorState(message: String) -> some View {
        CLEmptyState(
            systemImage: "exclamationmark.triangle.fill",
            title: "Couldn't open this circle",
            message: message,
            actionTitle: "Retry",
            actionAccessibilityLabel: "Retry loading community"
        ) {
            Task { await viewModel.load() }
        }
    }

    @ViewBuilder
    private func membershipButtonLabel(title: String, isLoading: Bool) -> some View {
        Group {
            if isLoading {
                ProgressView()
                    .tint(viewModel.isMember ? CLColor.ink : CLColor.onPrimary)
            } else {
                Text(title)
            }
        }
    }

    private func memberCountLabel(for count: Int) -> String {
        count == 1 ? "1 member" : "\(count) members"
    }
}

// MARK: - Member row

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
                .font(CLTypography.bodyMedium)
                .foregroundStyle(CLColor.ink)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.vertical, CLSpacing.xs)
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
