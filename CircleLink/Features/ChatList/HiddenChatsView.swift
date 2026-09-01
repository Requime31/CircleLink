import SwiftUI

/// Soft-hidden chats — same rows as the main list, with Unhide in the context menu.
/// Uses the parent `NavigationStack` path (no nested stack).
struct HiddenChatsView: View {
    @ObservedObject var viewModel: ChatsViewModel
    @Binding var path: NavigationPath

    /// Separate from the main list search so typing there doesn’t filter this screen.
    @State private var searchText = ""
    @State private var previewCache: [String: [ChatMessageItem]] = [:]
    @State private var previewLoadingIds: Set<String> = []
    @FocusState private var isSearchFocused: Bool

    private var chats: [ChatSummary] {
        viewModel.filteredHiddenChats(matching: searchText)
    }

    var body: some View {
        VStack(spacing: 0) {
            searchField

            Group {
                if chats.isEmpty {
                    emptyState
                } else {
                    chatsList(chats)
                }
            }
        }
        .clCanvasBackground()
        .navigationTitle("Hidden Chats")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await viewModel.loadChats(showLoading: false)
        }
    }

    private var searchField: some View {
        HStack(spacing: CLSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(CLColor.inkMuted)
                .accessibilityHidden(true)

            TextField("Search hidden", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($isSearchFocused)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(CLColor.inkMuted)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, CLSpacing.md)
        .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
        .background(CLColor.surfaceSoft)
        .clipShape(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous))
        .padding(.horizontal, CLSpacing.screenHorizontal)
        .padding(.vertical, CLSpacing.sm)
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
            .listRowInsets(ChatListRowView.listRowInsets)
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
                    messages: previewCache[chat.id] ?? [],
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

    @ViewBuilder
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
        if previewCache[chatId] != nil || previewLoadingIds.contains(chatId) {
            return
        }
        previewLoadingIds.insert(chatId)
        let messages = await viewModel.fetchConversationPreview(chatId: chatId)
        previewCache[chatId] = messages
        previewLoadingIds.remove(chatId)
    }
}
