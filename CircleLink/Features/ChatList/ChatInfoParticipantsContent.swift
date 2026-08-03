import SwiftUI

/// Loaded Chat Info body: header, participants, and leave action for groups.
struct ChatInfoParticipantsContent: View {
    @ObservedObject var viewModel: ChatInfoViewModel
    let info: ChatInfo
    let onSelectPeer: (String, String?) -> Void
    let onLeaveTapped: () -> Void

    var body: some View {
        let participants = viewModel.displayParticipants(from: info)

        List {
            Section {
                header
                    .listRowBackground(CLColor.canvas)
                    .listRowSeparator(.hidden)
            }

            Section {
                if participants.isEmpty {
                    Text(info.type == .group ? "No members yet." : "No other person in this chat.")
                        .font(CLTypography.subheadline)
                        .foregroundStyle(CLColor.inkSecondary)
                        .listRowBackground(CLColor.surface)
                } else {
                    ForEach(participants) { user in
                        participantRow(user: user, communityId: info.communityId)
                    }
                }
            } header: {
                Text(info.type == .group ? "Members" : "Person")
                    .font(CLTypography.caption)
                    .foregroundStyle(CLColor.inkMuted)
                    .textCase(nil)
            }

            if info.type == .group {
                Section {
                    Button(role: .destructive, action: onLeaveTapped) {
                        HStack {
                            Spacer()
                            if viewModel.isLeaving {
                                ProgressView()
                                    .tint(CLColor.error)
                            } else {
                                Text("Leave Chat")
                                    .font(CLTypography.button)
                            }
                            Spacer()
                        }
                    }
                    .disabled(viewModel.isLeaving)
                    .accessibilityLabel("Leave chat")
                    .accessibilityHint("Leaves the chat only, not the community")
                    .listRowBackground(CLColor.surface)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .clAppear()
    }

    private var header: some View {
        VStack(spacing: CLSpacing.sm) {
            Image(systemName: info.type == .group ? "person.3.fill" : "person.fill")
                .font(.system(size: 28))
                .foregroundStyle(CLColor.inkMuted)
                .padding(CLSpacing.md)
                .background(Circle().fill(CLColor.primarySoft))
                .accessibilityHidden(true)

            Text(info.title)
                .font(CLTypography.title2)
                .foregroundStyle(CLColor.ink)
                .multilineTextAlignment(.center)

            Text(info.type == .group ? "Group chat" : "Direct chat")
                .font(CLTypography.subheadline)
                .foregroundStyle(CLColor.inkSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, CLSpacing.sm)
    }

    @ViewBuilder
    private func participantRow(user: User, communityId: String?) -> some View {
        let isSelf = user.id == viewModel.currentUserId
        let displayName = user.displayName.isEmpty ? "Member" : user.displayName

        if isSelf {
            ChatParticipantRowView(user: user, subtitle: "You", showsChevron: false)
                .accessibilityLabel("\(displayName), You")
                .listRowBackground(CLColor.surface)
        } else {
            Button {
                onSelectPeer(user.id, communityId)
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
