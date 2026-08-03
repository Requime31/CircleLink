import SwiftUI

struct ChatListView: View {
    @ObservedObject var viewModel: ChatsViewModel
    @Binding var pendingChatRoute: ChatThreadRoute?
    let makeChatViewModel: (String, String) -> ChatViewModel?
    let makeChatInfoViewModel: (String) -> ChatInfoViewModel
    let makePeerProfileSheet: (String, String?) -> PeerProfileSheet

    @State private var path = NavigationPath()
    @State private var previewCache: [String: ChatsViewModel.ConversationPreview] = [:]
    @State private var previewLoadingIds: Set<String> = []

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                switch viewModel.state {
                case .idle, .loading:
                    ProgressView("Loading chats…")
                        .tint(CLColor.primary)
                        .foregroundStyle(CLColor.inkMuted)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .empty:
                    emptyState
                case let .error(message):
                    errorState(message: message)
                case .loaded:
                    mainListContent
                }
            }
            .clCanvasBackground()
            .navigationTitle("Chats")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        path.append(HiddenChatsRoute())
                    } label: {
                        Image(systemName: "eye.slash")
                    }
                    .accessibilityLabel(
                        viewModel.hiddenCount > 0
                            ? "Hidden chats, \(viewModel.hiddenCount)"
                            : "Hidden chats"
                    )
                }
            }
            .searchable(
                text: $viewModel.searchText,
                placement: .navigationBarDrawer(displayMode: .automatic),
                prompt: "Search chats"
            )
            .navigationDestination(for: ChatThreadRoute.self) { route in
                chatThreadDestination(route)
            }
            .navigationDestination(for: ChatInfoRoute.self) { route in
                ChatInfoView(
                    viewModel: makeChatInfoViewModel(route.chatId),
                    makePeerProfileSheet: makePeerProfileSheet,
                    onLeftChat: {
                        path = NavigationPath()
                        Task { await viewModel.loadChats() }
                    }
                )
            }
            .navigationDestination(for: HiddenChatsRoute.self) { _ in
                HiddenChatsView(
                    viewModel: viewModel,
                    path: $path
                )
            }
            .task {
                await viewModel.loadChats()
            }
            .refreshable {
                await viewModel.loadChats()
            }
            .onAppear {
                consumePendingChatRoute()
            }
            .onChange(of: pendingChatRoute) { _ in
                consumePendingChatRoute()
            }
            .alert(
                "Something went wrong",
                isPresented: Binding(
                    get: { viewModel.actionErrorMessage != nil },
                    set: { if !$0 { viewModel.clearActionError() } }
                )
            ) {
                Button("OK", role: .cancel) { viewModel.clearActionError() }
            } message: {
                Text(viewModel.actionErrorMessage ?? "")
            }
        }
    }

    @ViewBuilder
    private var mainListContent: some View {
        let chats = viewModel.filteredVisibleChats

        if chats.isEmpty {
            searchEmptyState
        } else {
            chatsList(chats)
        }
    }

    private func consumePendingChatRoute() {
        guard let route = pendingChatRoute else { return }
        path = NavigationPath()
        path.append(route)
        pendingChatRoute = nil
    }

    @ViewBuilder
    private func chatThreadDestination(_ route: ChatThreadRoute) -> some View {
        if let chatViewModel = makeChatViewModel(route.chatId, route.title) {
            ChatThreadView(
                viewModel: chatViewModel,
                makePeerProfileSheet: makePeerProfileSheet,
                onOpenChatInfo: {
                    path.append(ChatInfoRoute(chatId: route.chatId))
                }
            )
        } else {
            Text("Unable to open chat.")
                .font(CLTypography.body)
                .foregroundStyle(CLColor.inkSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clCanvasBackground()
        }
    }

    @ViewBuilder
    private func chatsList(_ chats: [ChatSummary]) -> some View {
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

    /// One list row: open chat, mute/hide menu, conversation peek.
    @ViewBuilder
    private func chatRow(_ chat: ChatSummary) -> some View {
        Button {
            openThread(
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
                openThread(
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

    private func openThread(_ route: ChatThreadRoute) {
        path.append(route)
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

    private var emptyState: some View {
        CLEmptyState(
            systemImage: "bubble.left.and.bubble.right",
            title: "No chats yet",
            message: "Accept a Connect request to start a conversation.",
            actionTitle: "Refresh",
            actionAccessibilityLabel: "Refresh chats list"
        ) {
            Task { await viewModel.loadChats() }
        }
    }

    private var searchEmptyState: some View {
        CLEmptyState(
            systemImage: "magnifyingglass",
            title: "No chats found",
            message: "Try a different name or message."
        )
    }

    private func errorState(message: String) -> some View {
        CLEmptyState(
            systemImage: "exclamationmark.triangle",
            title: message,
            systemImageColor: CLColor.error,
            actionTitle: "Retry",
            actionAccessibilityLabel: "Retry loading chats",
            titleAccessibilityLabel: "Error: \(message)"
        ) {
            Task { await viewModel.loadChats() }
        }
    }
}
