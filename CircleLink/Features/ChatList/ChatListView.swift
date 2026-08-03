import SwiftUI

struct ChatListView: View {
    @ObservedObject var viewModel: ChatsViewModel
    @Binding var pendingChatRoute: ChatThreadRoute?
    let makeChatViewModel: (String, String) -> ChatViewModel?
    let makeChatInfoViewModel: (String) -> ChatInfoViewModel
    let makePeerProfileSheet: (String, String?) -> PeerProfileSheet

    @State private var path = NavigationPath()

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
                    ChatListLoadedContent(viewModel: viewModel) { route in
                        path.append(route)
                    }
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
