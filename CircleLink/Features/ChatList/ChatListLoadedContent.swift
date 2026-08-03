import SwiftUI

/// Visible chats list with mute/hide menu and conversation peek previews.
struct ChatListLoadedContent: View {
    @ObservedObject var viewModel: ChatsViewModel
    let onOpenThread: (ChatThreadRoute) -> Void

    @State private var previewCache: [String: ChatsViewModel.ConversationPreview] = [:]
    @State private var previewLoadingIds: Set<String> = []

    var body: some View {
        let chats = viewModel.filteredVisibleChats

        if chats.isEmpty {
            CLEmptyState(
                systemImage: "magnifyingglass",
                title: "No chats found",
                message: "Try a different name or message."
            )
        } else {
            List {
                ForEach(chats) { chat in
                    chatRow(chat)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(CLColor.canvas)
            .clAppear()
        }
    }

    @ViewBuilder
    private func chatRow(_ chat: ChatSummary) -> some View {
        Button {
            onOpenThread(
                ChatThreadRoute(
                    chatId: chat.id,
                    title: chat.title,
                    communityId: chat.communityId
                )
            )
        } label: {
            ChatListRowView(chat: chat)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(ChatListAccessibility.label(for: chat))
        .listRowBackground(CLColor.canvas)
        .listRowSeparatorTint(CLColor.hairline)
        .contextMenu {
            Button {
                onOpenThread(
                    ChatThreadRoute(
                        chatId: chat.id,
                        title: chat.title,
                        communityId: chat.communityId
                    )
                )
            } label: {
                Label("Open Chat", systemImage: "bubble.left")
            }

            Button {
                Task {
                    await viewModel.setMuted(chatId: chat.id, muted: !chat.isMuted)
                }
            } label: {
                Label(
                    chat.isMuted ? "Unmute" : "Mute",
                    systemImage: chat.isMuted ? "bell" : "bell.slash"
                )
            }

            Button(role: .destructive) {
                Task { await viewModel.hideChat(chatId: chat.id) }
            } label: {
                Label("Hide", systemImage: "eye.slash")
            }
        } preview: {
            ConversationPeekPreview(
                chatTitle: chat.title,
                isGroup: chat.type == .group,
                preview: previewCache[chat.id],
                isLoading: previewLoadingIds.contains(chat.id)
            )
            .task {
                await loadPreviewIfNeeded(for: chat.id)
            }
        }
    }

    private func loadPreviewIfNeeded(for chatId: String) async {
        if case .loaded? = previewCache[chatId] {
            return
        }
        if previewLoadingIds.contains(chatId) {
            return
        }
        previewLoadingIds.insert(chatId)
        let preview = await viewModel.fetchConversationPreview(chatId: chatId)
        if let preview {
            previewCache[chatId] = preview
        }
        previewLoadingIds.remove(chatId)
    }
}
