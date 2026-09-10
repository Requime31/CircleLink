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
            CLChatParticipantRow(
                name: displayName,
                detail: "You",
                avatarURL: user.avatarURL,
                avatarBase64: user.avatarBase64
            ) {
                EmptyView()
            }
                .accessibilityLabel("\(displayName), You")
                .listRowBackground(CLColor.surface)
        } else {
            Button {
                presentedPeer = ChatPeerSheetItem(userId: user.id, communityId: info.communityId)
            } label: {
                CLChatParticipantRow(
                    name: displayName,
                    avatarURL: user.avatarURL,
                    avatarBase64: user.avatarBase64
                ) {
                    CLDisclosureIndicator()
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(displayName)
            .accessibilityHint("Opens profile")
            .listRowBackground(CLColor.surface)
        }
    }
}

struct ChatPeerSheetItem: Identifiable {
    let userId: String
    let communityId: String?
    var id: String { userId }
}
