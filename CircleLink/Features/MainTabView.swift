import SwiftUI

struct MainTabView: View {
    @Binding var selectedTab: AppCoordinator.MainTab

    @ObservedObject var communitiesViewModel: CommunitiesViewModel
    @ObservedObject var chatsViewModel: ChatsViewModel
    @ObservedObject var connectViewModel: ConnectViewModel
    @ObservedObject var profileViewModel: ProfileViewModel

    let makeCommunityDetailViewModel: (String) -> CommunityDetailViewModel
    let onChatSelected: (String) -> Void
    let onCommunitySelected: (String) -> Void
    let onOpenGroupChat: (String, String) -> Void
    let onSignOut: () -> Void

    var body: some View {
        TabView(selection: $selectedTab) {
            CommunitiesListView(
                viewModel: communitiesViewModel,
                makeDetailViewModel: makeCommunityDetailViewModel,
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
                onChatSelected: onChatSelected
            )
            .tabItem {
                Label("Chats", systemImage: "bubble.left.and.bubble.right")
            }
            .accessibilityLabel("Chats tab")
            .tag(AppCoordinator.MainTab.chats)

            ConnectView(viewModel: connectViewModel)
                .tabItem {
                    Label("Connect", systemImage: "link")
                }
                .accessibilityLabel("Connect tab")
                .tag(AppCoordinator.MainTab.connect)

            ProfileView(
                viewModel: profileViewModel,
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
