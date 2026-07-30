import SwiftUI

struct ChatListView: View {
    @ObservedObject var viewModel: ChatsViewModel
    @Binding var pendingChatRoute: ChatThreadRoute?
    let makeChatViewModel: (String, String) -> ChatViewModel?
    let makeChatInfoViewModel: (String) -> ChatInfoViewModel
    let makePeerProfileSheet: (String, String?) -> PeerProfileSheet

    @State private var path = NavigationPath()
    @State private var previewCache: [String: [ChatMessageItem]] = [:]
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
                        messages: previewCache[chat.id] ?? [],
                        isLoading: previewLoadingIds.contains(chat.id)
                    )
                    .task {
                        await loadPreviewIfNeeded(for: chat.id)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(CLColor.canvas)
        .clAppear()
    }

    private func openThread(_ route: ChatThreadRoute) {
        path.append(route)
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
        VStack(spacing: CLSpacing.sm) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundStyle(CLColor.inkMuted)
                .padding(CLSpacing.md)
                .background(Circle().fill(CLColor.primarySoft))
                .accessibilityHidden(true)
            Text("No chats yet")
                .font(CLTypography.title2)
                .foregroundStyle(CLColor.ink)
            Text("Accept a Connect request to start a conversation.")
                .font(CLTypography.subheadline)
                .foregroundStyle(CLColor.inkSecondary)
                .multilineTextAlignment(.center)
            Button("Refresh") {
                Task { await viewModel.loadChats() }
            }
            .buttonStyle(CLSecondaryButtonStyle())
            .padding(.top, CLSpacing.xs)
            .accessibilityLabel("Refresh chats list")
        }
        .padding(CLSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var searchEmptyState: some View {
        VStack(spacing: CLSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(CLColor.inkMuted)
                .padding(CLSpacing.md)
                .background(Circle().fill(CLColor.surfaceSoft))
                .accessibilityHidden(true)
            Text("No chats found")
                .font(CLTypography.title2)
                .foregroundStyle(CLColor.ink)
            Text("Try a different name or message.")
                .font(CLTypography.subheadline)
                .foregroundStyle(CLColor.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(CLSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: CLSpacing.sm) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(CLColor.error)
                .padding(CLSpacing.md)
                .background(Circle().fill(CLColor.errorSoft))
                .accessibilityHidden(true)
            Text(message)
                .font(CLTypography.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(CLColor.inkSecondary)
                .accessibilityLabel("Error: \(message)")
            Button("Retry") {
                Task { await viewModel.loadChats() }
            }
            .buttonStyle(CLSecondaryButtonStyle())
            .padding(.top, CLSpacing.xs)
            .accessibilityLabel("Retry loading chats")
        }
        .padding(CLSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
