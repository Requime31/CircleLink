import SwiftUI

/// Per-tab routers owned by the composition root / coordinator.
/// Collapses MainTabView's dependency relay into one assembly value.
@MainActor
struct MainTabAssembly {
    let communities: CommunitiesTabRouter
    let chats: ChatsTabRouter
    let connect: ConnectTabRouter
    let profile: ProfileTabRouter
}

@MainActor
struct CommunitiesTabRouter {
    let viewModel: CommunitiesViewModel
    let makeDetailViewModel: (String) -> CommunityDetailViewModel
    let makeFeedViewModel: (String) -> CommunityFeedViewModel
    let makePeerProfileSheet: (String, String?) -> PeerProfileSheet
    let onCommunitySelected: (String) -> Void
    let onOpenGroupChat: (String, String) -> Void

    @ViewBuilder
    var rootView: some View {
        CommunitiesListView(
            viewModel: viewModel,
            makeDetailViewModel: makeDetailViewModel,
            makeFeedViewModel: makeFeedViewModel,
            makePeerProfileSheet: makePeerProfileSheet,
            onCommunitySelected: onCommunitySelected,
            onOpenGroupChat: onOpenGroupChat
        )
    }
}

@MainActor
struct ChatsTabRouter {
    let viewModel: ChatsViewModel
    let makeChatViewModel: (String, String) -> ChatViewModel?
    let makeChatInfoViewModel: (String) -> ChatInfoViewModel
    let makePeerProfileSheet: (String, String?) -> PeerProfileSheet

    @ViewBuilder
    func rootView(pendingChatRoute: Binding<ChatThreadRoute?>) -> some View {
        ChatListView(
            viewModel: viewModel,
            pendingChatRoute: pendingChatRoute,
            makeChatViewModel: makeChatViewModel,
            makeChatInfoViewModel: makeChatInfoViewModel,
            makePeerProfileSheet: makePeerProfileSheet
        )
    }
}

@MainActor
struct ConnectTabRouter {
    let tabModel: ConnectTabModel
    let makePeerProfileSheet: (String, String?) -> PeerProfileSheet

    @ViewBuilder
    var rootView: some View {
        ConnectView(
            tab: tabModel,
            makePeerProfileSheet: makePeerProfileSheet
        )
    }
}

@MainActor
struct ProfileTabRouter {
    let viewModel: ProfileViewModel
    let makeSettingsViewModel: () -> SettingsViewModel
    let onSignOut: () -> Void

    @ViewBuilder
    var rootView: some View {
        ProfileView(
            viewModel: viewModel,
            makeSettingsViewModel: makeSettingsViewModel,
            onSignOut: onSignOut
        )
    }
}
