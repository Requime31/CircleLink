import SwiftUI

/// Participants list pushed from Chat Info (“View Participants”).
struct ChatParticipantsView: View {
    let info: ChatInfo
    let currentUserId: String
    let makePeerProfileSheet: (String, PeerProfileMode) -> PeerProfileSheet

    @State private var presentedPeer: ChatPeerSheetItem?

    var body: some View {
        let participants = displayParticipants

        List {
            if participants.isEmpty {
                Text(info.type == .group ? "No members yet." : "No other person in this chat.")
                    .font(CLTypography.subheadline)
                    .foregroundStyle(CLColor.inkSecondary)
                    .listRowBackground(CLColor.surface)
            } else {
                ForEach(participants) { user in
                    participantRow(user: user)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .clCanvasBackground()
        .navigationTitle(info.type == .group ? "Participants" : "Person")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $presentedPeer) { item in
            makePeerProfileSheet(item.userId, .social)
        }
    }

    private var displayParticipants: [User] {
        if info.type == .direct {
            return info.participants.filter { $0.id != currentUserId }
        }
        return info.participants.sorted { lhs, rhs in
            if lhs.id == currentUserId { return false }
            if rhs.id == currentUserId { return true }
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    @ViewBuilder
    private func participantRow(user: User) -> some View {
        let isSelf = user.id == currentUserId
        let displayName = user.displayName.isEmpty ? "Member" : user.displayName

        if isSelf {
            ChatParticipantRowView(user: user, subtitle: "You", showsChevron: false)
                .accessibilityLabel("\(displayName), You")
                .listRowBackground(CLColor.surface)
        } else {
            Button {
                presentedPeer = ChatPeerSheetItem(userId: user.id, communityId: info.communityId)
            } label: {
                ChatParticipantRowView(user: user, subtitle: nil, showsChevron: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(displayName)
            .accessibilityHint("Opens profile")
            .listRowBackground(CLColor.surface)
        }
    }
}

// MARK: - Shared row

struct ChatParticipantRowView: View {
    static let avatarSize: CGFloat = 44

    let user: User
    var subtitle: String?
    var showsChevron: Bool = true

    var body: some View {
        HStack(spacing: CLSpacing.sm) {
            AvatarImageView(
                localPreview: nil,
                avatarBase64: user.avatarBase64,
                avatarURL: user.avatarURL,
                size: Self.avatarSize,
                clip: .chat
            )

            VStack(alignment: .leading, spacing: CLSpacing.xxs) {
                Text(user.displayName.isEmpty ? "Member" : user.displayName)
                    .font(CLTypography.headline)
                    .foregroundStyle(CLColor.ink)

                if let subtitle {
                    Text(subtitle)
                        .font(CLTypography.caption)
                        .foregroundStyle(CLColor.inkMuted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CLColor.inkMuted)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, CLSpacing.xxs)
        .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
        .contentShape(Rectangle())
    }
}

struct ChatPeerSheetItem: Identifiable {
    let userId: String
    let communityId: String?
    var id: String { userId }
}
