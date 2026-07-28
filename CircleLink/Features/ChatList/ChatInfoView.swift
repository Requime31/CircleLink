import SwiftUI

/// Chat Info (DM) / Members (group). Opened from the chats list context menu.
/// Owns its ViewModel via `@StateObject` so navigation re-renders don’t reset load state.
struct ChatInfoView: View {
    @StateObject private var viewModel: ChatInfoViewModel
    let makePeerProfileSheet: (String, String?) -> PeerProfileSheet
    /// Called after a successful leave so the list can refresh and pop.
    let onLeftChat: () -> Void

    @State private var presentedPeer: ChatPeerSheetItem?
    @State private var showLeaveConfirmation = false

    init(
        viewModel: @autoclosure @escaping () -> ChatInfoViewModel,
        makePeerProfileSheet: @escaping (String, String?) -> PeerProfileSheet,
        onLeftChat: @escaping () -> Void
    ) {
        _viewModel = StateObject(wrappedValue: viewModel())
        self.makePeerProfileSheet = makePeerProfileSheet
        self.onLeftChat = onLeftChat
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                ProgressView("Loading…")
                    .tint(CLColor.primary)
                    .foregroundStyle(CLColor.inkMuted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .empty:
                emptyState(message: "No participants found.")
            case let .error(message):
                errorState(message: message)
            case let .loaded(info):
                participantsContent(info)
            }
        }
        .clCanvasBackground()
        .navigationTitle(viewModel.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel.load()
        }
        .onDisappear {
            viewModel.cancelLoad()
        }
        .sheet(item: $presentedPeer) { item in
            makePeerProfileSheet(item.userId, item.communityId)
        }
        .alert("Leave this chat?", isPresented: $showLeaveConfirmation) {
            Button("Leave Chat", role: .destructive) {
                Task { await confirmLeave() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You leave the chat only. You stay in the community.")
        }
        .alert(
            "Couldn’t leave chat",
            isPresented: Binding(
                get: { viewModel.leaveErrorMessage != nil },
                set: { if !$0 { viewModel.clearLeaveError() } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.leaveErrorMessage ?? "")
        }
    }

    @ViewBuilder
    private func participantsContent(_ info: ChatInfo) -> some View {
        let participants = viewModel.displayParticipants(from: info)

        List {
            Section {
                header(for: info)
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
                    Button(role: .destructive) {
                        showLeaveConfirmation = true
                    } label: {
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

    private func header(for info: ChatInfo) -> some View {
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
                presentedPeer = ChatPeerSheetItem(userId: user.id, communityId: communityId)
            } label: {
                ChatParticipantRowView(user: user, subtitle: nil, showsChevron: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(displayName)
            .accessibilityHint("Opens profile")
            .listRowBackground(CLColor.surface)
        }
    }

    private func emptyState(message: String) -> some View {
        Text(message)
            .font(CLTypography.body)
            .foregroundStyle(CLColor.inkSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: CLSpacing.sm) {
            Text(message)
                .font(CLTypography.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(CLColor.inkSecondary)
            Button("Retry") {
                viewModel.load()
            }
            .buttonStyle(CLSecondaryButtonStyle())
        }
        .padding(CLSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func confirmLeave() async {
        let success = await viewModel.leaveChat()
        if success {
            onLeftChat()
        }
    }
}

// MARK: - Row

private struct ChatParticipantRowView: View {
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
                size: Self.avatarSize
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

/// Sheet identity for `.sheet(item:)`.
private struct ChatPeerSheetItem: Identifiable {
    let userId: String
    let communityId: String?
    var id: String { userId }
}
