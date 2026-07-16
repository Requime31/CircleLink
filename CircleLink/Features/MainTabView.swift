import SwiftUI

struct MainTabView: View {
    @ObservedObject var communitiesViewModel: CommunitiesViewModel
    @ObservedObject var chatsViewModel: ChatsViewModel
    @ObservedObject var connectViewModel: ConnectViewModel
    @ObservedObject var profileViewModel: ProfileViewModel

    let makeCommunityDetailViewModel: (String) -> CommunityDetailViewModel
    let onChatSelected: (String) -> Void
    let onCommunitySelected: (String) -> Void
    let onOpenGroupChat: (String) -> Void
    let onOpenDebugChat: () -> Void
    let onSignOut: () -> Void

    var body: some View {
        TabView {
            CommunitiesListView(
                viewModel: communitiesViewModel,
                makeDetailViewModel: makeCommunityDetailViewModel,
                onCommunitySelected: onCommunitySelected,
                onOpenGroupChat: onOpenGroupChat
            )
            .tabItem {
                Label("Communities", systemImage: "person.3")
            }

            ChatListView(
                viewModel: chatsViewModel,
                onChatSelected: onChatSelected
            )
            .tabItem {
                Label("Chats", systemImage: "bubble.left.and.bubble.right")
            }

            ConnectView(viewModel: connectViewModel)
                .tabItem {
                    Label("Connect", systemImage: "link")
                }

            ProfileView(
                viewModel: profileViewModel,
                onSignOut: onSignOut,
                onOpenDebugChat: onOpenDebugChat
            )
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
        }
    }
}
