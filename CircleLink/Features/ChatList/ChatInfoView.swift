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
                CLEmptyState(
                    systemImage: "person.2",
                    title: "No participants found."
                )
            case let .error(message):
                CLEmptyState(
                    systemImage: "exclamationmark.triangle",
                    title: message,
                    systemImageColor: CLColor.error,
                    actionTitle: "Retry",
                    actionAccessibilityLabel: "Retry loading chat info",
                    titleAccessibilityLabel: "Error: \(message)"
                ) {
                    viewModel.load()
                }
            case let .loaded(info):
                ChatInfoParticipantsContent(
                    viewModel: viewModel,
                    info: info,
                    onSelectPeer: { userId, communityId in
                        presentedPeer = ChatPeerSheetItem(userId: userId, communityId: communityId)
                    },
                    onLeaveTapped: { showLeaveConfirmation = true }
                )
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

    private func confirmLeave() async {
        let success = await viewModel.leaveChat()
        if success {
            onLeftChat()
        }
    }
}

/// Sheet identity for `.sheet(item:)`.
struct ChatPeerSheetItem: Identifiable {
    let userId: String
    let communityId: String?
    var id: String { userId }
}
