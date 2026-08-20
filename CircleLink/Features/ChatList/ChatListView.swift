import SwiftUI

struct ChatListView: View {
    @ObservedObject var viewModel: ChatsViewModel
    @Binding var pendingChatRoute: ChatThreadRoute?
    let makeChatViewModel: (String, String) -> ChatViewModel?
    let makeChatInfoViewModel: (String) -> ChatInfoViewModel
    let makePeerProfileSheet: (String, PeerProfileMode) -> PeerProfileSheet

    @State private var path = NavigationPath()
    @State private var previewCache: [String: [ChatMessageItem]] = [:]
    @State private var previewLoadingIds: Set<String> = []

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                switch viewModel.state {
                case .idle, .loading:
                    CLLoadingState(message: "Loading chats…")
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
            .navigationBarTitleDisplayMode(.large)
            .searchable(
                text: $viewModel.searchText,
                placement: .navigationBarDrawer(displayMode: .automatic),
                prompt: "Search chats"
            )
            .toolbarBackground(CLColor.canvas, for: .navigationBar, .tabBar)
            .toolbarBackground(.visible, for: .navigationBar, .tabBar)
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
                    },
                    onOpenMessage: { message in
                        openMessageFromSearch(message)
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
            .onReceive(NotificationCenter.default.publisher(for: .circleLinkChatListShouldReload)) { _ in
                Task { await viewModel.loadChats(showLoading: false) }
            }
            .onReceive(NotificationCenter.default.publisher(for: .circleLinkChatHistoryCleared)) { notification in
                if let chatId = notification.userInfo?[ChatHistoryClearedUserInfoKey.chatId] as? String {
                    previewCache.removeValue(forKey: chatId)
                } else {
                    previewCache.removeAll()
                }
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

        if chats.isEmpty && viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // Loaded but all hidden — still show hidden entry.
            chatsList([])
        } else if chats.isEmpty {
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
            Section {
                Button {
                    path.append(HiddenChatsRoute())
                } label: {
                    hiddenChatsRow
                }
                .buttonStyle(.plain)
                .listRowBackground(CLColor.canvas)
                .listRowInsets(ChatListRowView.listRowInsets)
                .listRowSeparatorTint(CLColor.hairline)
                .accessibilityLabel(
                    viewModel.hiddenCount > 0
                        ? "Hidden chats, \(viewModel.hiddenCount) conversations"
                        : "Hidden chats"
                )
            }
            .listSectionSeparator(.hidden, edges: [.top, .bottom])

            Section {
                ForEach(chats) { chat in
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
                    .listRowInsets(ChatListRowView.listRowInsets)
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

                        Button {
                            path.append(ChatInfoRoute(chatId: chat.id))
                        } label: {
                            Label("Info", systemImage: "info.circle")
                        }

                        Button {
                            Task { await viewModel.hideChat(chatId: chat.id) }
                        } label: {
                            Label("Hide", systemImage: "eye.slash")
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
            }
            .listSectionSeparator(.hidden, edges: [.top, .bottom])
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(CLColor.canvas)
        .clAppear()
    }

    private var hiddenChatsRow: some View {
        HStack(spacing: CLSpacing.md) {
            Image(systemName: "archivebox")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(CLColor.inkSecondary)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous)
                        .fill(CLColor.surfaceSoft)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("Hidden Chats")
                    .font(CLTypography.footnote)
                    .foregroundStyle(CLColor.ink)
                Text(
                    viewModel.hiddenCount == 0
                        ? "No hidden conversations"
                        : "\(viewModel.hiddenCount) conversations"
                )
                .font(CLTypography.caption)
                .foregroundStyle(CLColor.inkSecondary)
            }

            Spacer(minLength: CLSpacing.xs)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(CLColor.inkMuted)
        }
        .padding(.vertical, CLSpacing.sm)
        .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
        .contentShape(Rectangle())
    }

    private func openThread(_ route: ChatThreadRoute) {
        path.append(route)
    }

    /// Search → dismiss Info → land on thread and scroll to the hit.
    private func openMessageFromSearch(_ message: Message) {
        NotificationCenter.default.post(
            name: .circleLinkRevealChatMessage,
            object: nil,
            userInfo: [
                ChatRevealMessageUserInfoKey.chatId: message.chatId,
                ChatRevealMessageUserInfoKey.messageId: message.id
            ]
        )
        // Pop Chat Info (Search already cleared via destination = nil).
        if !path.isEmpty {
            path.removeLast()
        }
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
        .clAppear()
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
            title: "Something went wrong",
            message: message,
            actionTitle: "Retry",
            actionAccessibilityLabel: "Retry loading chats",
            titleAccessibilityLabel: "Error: \(message)"
        ) {
            Task { await viewModel.loadChats() }
        }
    }
}
