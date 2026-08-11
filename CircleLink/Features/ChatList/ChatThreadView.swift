import SwiftUI

/// Pushed chat screen: UIKit thread + SwiftUI toolbar (Chat Info) + Peer Profile sheet.
struct ChatThreadView: View {
    @StateObject private var viewModel: ChatViewModel
    let makePeerProfileSheet: (String, PeerProfileMode) -> PeerProfileSheet
    let onOpenChatInfo: () -> Void

    @State private var presentedPeer: ChatThreadPeerItem?

    init(
        viewModel: @autoclosure @escaping () -> ChatViewModel,
        makePeerProfileSheet: @escaping (String, PeerProfileMode) -> PeerProfileSheet,
        onOpenChatInfo: @escaping () -> Void
    ) {
        _viewModel = StateObject(wrappedValue: viewModel())
        self.makePeerProfileSheet = makePeerProfileSheet
        self.onOpenChatInfo = onOpenChatInfo
    }

    var body: some View {
        ChatViewControllerWrapper(
            viewModel: viewModel,
            onSenderAvatarTapped: { userId in
                presentedPeer = ChatThreadPeerItem(
                    userId: userId,
                    communityId: viewModel.communityId
                )
            }
        )
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Button(action: onOpenChatInfo) {
                    VStack(spacing: 2) {
                        Text(viewModel.chatTitle)
                            .font(CLTypography.headline)
                            .foregroundStyle(CLColor.ink)
                            .lineLimit(1)
                        Text(viewModel.isGroupChat ? "Tap for members" : "Tap for info")
                            .font(CLTypography.caption)
                            .foregroundStyle(CLColor.inkMuted)
                    }
                }
                .accessibilityLabel(viewModel.chatTitle)
                .accessibilityHint(viewModel.isGroupChat ? "Opens members" : "Opens chat info")
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onOpenChatInfo) {
                    Image(systemName: viewModel.isGroupChat ? "person.3" : "info.circle")
                }
                .accessibilityLabel(viewModel.isGroupChat ? "Members" : "Chat info")
            }
        }
        .sheet(item: $presentedPeer) { item in
            makePeerProfileSheet(item.userId, .social)
        }
    }
}

private struct ChatThreadPeerItem: Identifiable {
    let userId: String
    let communityId: String?
    var id: String { userId }
}
