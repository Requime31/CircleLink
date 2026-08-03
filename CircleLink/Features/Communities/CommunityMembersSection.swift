import SwiftUI

/// Members list for community detail, with peer-profile taps for others.
struct CommunityMembersSection: View {
    @ObservedObject var viewModel: CommunityDetailViewModel
    let onSelectPeer: (String) -> Void

    var body: some View {
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
                onSelectPeer(member.id)
            } label: {
                MemberRowView(user: member, showsChevron: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("View profile for \(displayName)")
            .accessibilityHint("Opens member profile")
        }
    }
}

struct MemberRowView: View {
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
