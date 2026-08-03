import SwiftUI

/// Soft-hidden chats — same rows as the main list, with Unhide in the context menu.
/// Uses the parent `NavigationStack` path (no nested stack).
struct HiddenChatsView: View {
    @ObservedObject var viewModel: ChatsViewModel
    @Binding var path: NavigationPath

    /// Separate from the main list search so typing there doesn’t filter this screen.
    @State private var searchText = ""
    @State private var previewCache: [String: ChatsViewModel.ConversationPreview] = [:]
    @State private var previewLoadingIds: Set<String> = []

    private var chats: [ChatSummary] {
        viewModel.filteredHiddenChats(matching: searchText)
    }

    var body: some View {
        Group {
            if chats.isEmpty {
                emptyState
            } else {
                chatsList(chats)
            }
        }
        .clCanvasBackground()
        .navigationTitle("Hidden chats")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search hidden"
        )
        .refreshable {
            await viewModel.loadChats(showLoading: false)
        }
    }

    @ViewBuilder
    private func chatsList(_ chats: [ChatSummary]) -> some View {
        List(chats) { chat in
            Button {
                openThread(chat)
            } label: {
                ChatListRowView(chat: chat)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(ChatListAccessibility.label(for: chat))
            .listRowBackground(CLColor.canvas)
            .listRowSeparatorTint(CLColor.hairline)
            .contextMenu {
                Button {
                    openThread(chat)
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

                Button {
                    Task { await viewModel.unhideChat(chatId: chat.id) }
                } label: {
                    Label("Unhide", systemImage: "eye")
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
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(CLColor.canvas)
        .clAppear()
    }

    private var emptyState: some View {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            CLEmptyState(
                systemImage: "eye.slash",
                title: "No hidden chats",
                message: "Chats you hide show up here."
            )
        } else {
            CLEmptyState(
                systemImage: "magnifyingglass",
                title: "No chats found",
                message: "Try a different name or message."
            )
        }
    }

    private func openThread(_ chat: ChatSummary) {
        path.append(
            ChatThreadRoute(
                chatId: chat.id,
                title: chat.title,
                communityId: chat.communityId
            )
        )
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
