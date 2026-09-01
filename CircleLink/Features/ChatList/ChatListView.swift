import SwiftUI

struct ChatListView: View {
    @ObservedObject var viewModel: ChatsViewModel
    @Binding var pendingChatRoute: ChatThreadRoute?
    let makeChatViewModel: (String, String) -> ChatViewModel?
    let makeChatInfoViewModel: (String) -> ChatInfoViewModel
    let makePeerProfileSheet: (String, PeerProfileMode) -> PeerProfileSheet

    @State private var path = NavigationPath()
    @State private var editMode: EditMode = .inactive
    @State private var previewCache: [String: [ChatMessageItem]] = [:]
    @State private var previewLoadingIds: Set<String> = []
    @State private var isSearchPresented = false
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                chatScreenTitle

                if isSearchPresented {
                    chatSearchField
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

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
            }
            .clCanvasBackground()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if viewModel.pinnedChats.count > 1,
                       viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        EditButton()
                    }

                    Button {
                        toggleSearch()
                    } label: {
                        Image(systemName: isSearchPresented ? "xmark" : "magnifyingglass")
                    }
                    .accessibilityLabel(isSearchPresented ? "Close search" : "Search chats")
                }
            }
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
                await viewModel.loadChats(showLoading: false)
            }
            .onAppear {
                consumePendingChatRoute()
            }
            .onChange(of: pendingChatRoute) { _ in
                consumePendingChatRoute()
            }
            .onChange(of: path.count) { count in
                if count > 0 { editMode = .inactive }
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
        .environment(\.editMode, $editMode)
        .onDisappear { editMode = .inactive }
    }

    private var chatScreenTitle: some View {
        Text("Chats")
            .font(CLTypography.largeTitle)
            .foregroundStyle(CLColor.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, CLSpacing.screenHorizontal)
            .padding(.top, CLSpacing.xs)
            .padding(.bottom, CLSpacing.md)
            .background(CLColor.canvas)
            .zIndex(1)
            .accessibilityAddTraits(.isHeader)
    }

    private var chatSearchField: some View {
        HStack(spacing: CLSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(CLColor.inkMuted)

            TextField("Search chats", text: $viewModel.searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($isSearchFocused)

            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(CLColor.inkMuted)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, CLSpacing.md)
        .frame(minHeight: 44)
        .background(CLColor.surfaceSoft)
        .clipShape(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous))
        .padding(.horizontal, CLSpacing.screenHorizontal)
        .padding(.bottom, CLSpacing.sm)
    }

    private func toggleSearch() {
        withAnimation(.easeOut(duration: 0.2)) {
            isSearchPresented.toggle()
        }
        if isSearchPresented {
            DispatchQueue.main.async { isSearchFocused = true }
        } else {
            isSearchFocused = false
            viewModel.searchText = ""
        }
    }

    @ViewBuilder
    private var mainListContent: some View {
        let chats = viewModel.filteredVisibleChats

        if chats.isEmpty && viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // Loaded but all hidden — still show hidden entry.
            chatsList
        } else if chats.isEmpty {
            searchEmptyState
        } else {
            chatsList
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
    private var chatsList: some View {
        List {
            Button {
                path.append(HiddenChatsRoute())
            } label: {
                hiddenChatsRow
            }
            .buttonStyle(.plain)
            .listRowBackground(CLColor.canvas)
            .listRowInsets(ChatListRowView.listRowInsets)
            .listRowSeparatorTint(CLColor.hairline)
            .listRowSeparator(.visible, edges: .bottom)
            .accessibilityLabel(
                viewModel.hiddenCount > 0
                    ? "Hidden chats, \(viewModel.hiddenCount) conversations"
                    : "Hidden chats"
            )

            if !viewModel.pinnedChats.isEmpty {
                Text("Pinned")
                    .font(CLTypography.caption.weight(.semibold))
                    .foregroundStyle(CLColor.inkSecondary)
                    .textCase(.uppercase)
                    .listRowBackground(CLColor.canvas)
                    .listRowInsets(EdgeInsets(
                        top: CLSpacing.md,
                        leading: CLSpacing.screenHorizontal,
                        bottom: CLSpacing.xs,
                        trailing: CLSpacing.screenHorizontal
                    ))
                    .listRowSeparator(.hidden)

                ForEach(Array(viewModel.pinnedChats.enumerated()), id: \.element.id) { index, chat in
                    chatRow(chat, pinnedIndex: index, pinnedCount: viewModel.pinnedChats.count)
                }
                .onMove { source, destination in
                    var ids = viewModel.pinnedChats.map(\.id)
                    ids.move(fromOffsets: source, toOffset: destination)
                    Task { await viewModel.reorderPinnedChats(chatIds: ids) }
                }
                .listRowSeparator(.visible, edges: .bottom)
            }

            ForEach(viewModel.unpinnedChats) { chat in
                chatRow(chat)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(CLColor.canvas)
        .clAppear()
    }

    private func chatRow(
        _ chat: ChatSummary,
        pinnedIndex: Int? = nil,
        pinnedCount: Int = 0
    ) -> some View {
        Button {
            openThread(
                ChatThreadRoute(chatId: chat.id, title: chat.title, communityId: chat.communityId)
            )
        } label: {
            ChatListRowView(chat: chat)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(ChatListAccessibility.label(for: chat))
        .accessibilityValue(chat.isPinned ? "Pinned" : "")
        .accessibilityActions {
            if let pinnedIndex, pinnedIndex > 0 {
                Button("Move up") {
                    Task { await viewModel.movePinnedChat(chatId: chat.id, by: -1) }
                }
            }
            if let pinnedIndex, pinnedIndex < pinnedCount - 1 {
                Button("Move down") {
                    Task { await viewModel.movePinnedChat(chatId: chat.id, by: 1) }
                }
            }
        }
        .listRowBackground(CLColor.canvas)
        .listRowInsets(ChatListRowView.listRowInsets)
        .listRowSeparatorTint(CLColor.hairline)
        .contextMenu {
            Button {
                openThread(ChatThreadRoute(chatId: chat.id, title: chat.title, communityId: chat.communityId))
            } label: {
                Label("Open Chat", systemImage: "bubble.left")
            }

            Button {
                Task { await viewModel.setPinned(chatId: chat.id, pinned: !chat.isPinned) }
            } label: {
                Label(chat.isPinned ? "Unpin" : "Pin", systemImage: chat.isPinned ? "pin.slash" : "pin")
            }
            .disabled(viewModel.isPinMutationInFlight)

            Button {
                Task { await viewModel.setMuted(chatId: chat.id, muted: !chat.isMuted) }
            } label: {
                Label(chat.isMuted ? "Unmute" : "Mute", systemImage: chat.isMuted ? "bell" : "bell.slash")
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
            .task { await loadPreviewIfNeeded(for: chat.id) }
        }
    }

    private var hiddenChatsRow: some View {
        HStack(spacing: CLSpacing.md) {
            Image(systemName: "eye.slash")
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(CLColor.inkSecondary)
                .frame(width: 56, height: 56)
                .background(
                    Circle().fill(CLColor.surfaceSoft)
                )

            VStack(alignment: .leading, spacing: CLSpacing.xxs) {
                Text("Hidden Chats")
                    .font(CLTypography.body)
                    .foregroundStyle(CLColor.ink)
                Text(
                    viewModel.hiddenCount == 0
                        ? "No hidden conversations"
                        : "\(viewModel.hiddenCount) conversations"
                )
                .font(CLTypography.subheadline)
                .foregroundStyle(CLColor.inkSecondary)
            }

            Spacer(minLength: CLSpacing.xs)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(CLColor.inkMuted)
        }
        .padding(.vertical, ChatListRowView.rowVerticalPadding)
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
