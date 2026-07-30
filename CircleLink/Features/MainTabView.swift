import SwiftUI

struct MainTabView: View {
    @Binding var selectedTab: AppCoordinator.MainTab
    @Binding var pendingChatRoute: ChatThreadRoute?

    @ObservedObject var communitiesViewModel: CommunitiesViewModel
    @ObservedObject var chatsViewModel: ChatsViewModel
    @ObservedObject var connectViewModel: ConnectViewModel
    @ObservedObject var profileViewModel: ProfileViewModel

    let makeCommunityDetailViewModel: (String) -> CommunityDetailViewModel
    let makeChatViewModel: (String, String) -> ChatViewModel?
    let makeChatInfoViewModel: (String) -> ChatInfoViewModel
    let makePeerProfileSheet: (String, String?) -> PeerProfileSheet
    let pushHandler: PushNotificationHandler
    let onCommunitySelected: (String) -> Void
    let onOpenGroupChat: (String, String) -> Void
    let onSignOut: () -> Void

    var body: some View {
        TabView(selection: $selectedTab) {
            CommunitiesListView(
                viewModel: communitiesViewModel,
                makeDetailViewModel: makeCommunityDetailViewModel,
                makePeerProfileSheet: makePeerProfileSheet,
                onCommunitySelected: onCommunitySelected,
                onOpenGroupChat: onOpenGroupChat
            )
            .tabItem {
                Label("Communities", systemImage: "person.3")
            }
            .accessibilityLabel("Communities tab")
            .tag(AppCoordinator.MainTab.communities)

            ChatListView(
                viewModel: chatsViewModel,
                pendingChatRoute: $pendingChatRoute,
                makeChatViewModel: makeChatViewModel,
                makeChatInfoViewModel: makeChatInfoViewModel,
                makePeerProfileSheet: makePeerProfileSheet
            )
            .tabItem {
                Label("Chats", systemImage: "bubble.left.and.bubble.right")
            }
            .accessibilityLabel("Chats tab")
            .tag(AppCoordinator.MainTab.chats)

            ConnectView(
                viewModel: connectViewModel,
                makePeerProfileSheet: makePeerProfileSheet
            )
                .tabItem {
                    Label("Connect", systemImage: "link")
                }
                .accessibilityLabel("Connect tab")
                .tag(AppCoordinator.MainTab.connect)

            ProfileView(
                viewModel: profileViewModel,
                pushHandler: pushHandler,
                onSignOut: onSignOut
            )
            .tabItem {
                Label("Profile", systemImage: "person.circle")
            }
            .accessibilityLabel("Profile tab")
            .tag(AppCoordinator.MainTab.profile)
        }
        .tint(CLColor.primary)
    }
}
