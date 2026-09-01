import SwiftUI

/// Pushed chat screen: UIKit thread + SwiftUI toolbar (Chat Info) + Peer Profile sheet.
struct ChatThreadView: View {
    @StateObject private var viewModel: ChatViewModel
    let makePeerProfileSheet: (String, PeerProfileMode) -> PeerProfileSheet
    let onOpenChatInfo: () -> Void

    @State private var presentedPeer: ChatThreadPeerItem?
    @State private var presentedMedia: ChatThreadMediaItem?
    @State private var showBlockConfirmation = false
    @Environment(\.dismiss) private var dismiss

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
            },
            onImageAttachmentTapped: { url, data in
                presentedMedia = ChatThreadMediaItem(url: url, data: data)
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
                Menu {
                    Button(action: onOpenChatInfo) {
                        Label(viewModel.isGroupChat ? "Members" : "Chat info", systemImage: "info.circle")
                    }
                    if viewModel.canModeratePeer {
                        Button("Block…", role: .destructive) {
                            viewModel.prepareBlockConfirmation()
                            showBlockConfirmation = true
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Chat options")
            }
        }
        .sheet(item: $presentedPeer) { item in
            makePeerProfileSheet(item.userId, .social)
        }
        .fullScreenCover(item: $presentedMedia) { item in
            ChatMediaFullscreenView(url: item.url, localImageData: item.data)
        }
        .sheet(isPresented: $showBlockConfirmation) {
            BlockConfirmationView(
                peerName: viewModel.chatTitle,
                isBlocking: viewModel.isBlockingPeer,
                errorMessage: viewModel.moderationErrorMessage,
                onCancel: { showBlockConfirmation = false },
                onBlock: {
                    Task {
                        if await viewModel.blockPeer() {
                            showBlockConfirmation = false
                            dismiss()
                        }
                    }
                }
            )
        }
    }
}

private struct ChatThreadPeerItem: Identifiable {
    let userId: String
    let communityId: String?
    var id: String { userId }
}

private struct ChatThreadMediaItem: Identifiable {
    let id = UUID()
    let url: URL?
    let data: Data?
}
