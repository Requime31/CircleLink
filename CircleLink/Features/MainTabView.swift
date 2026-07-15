import SwiftUI

struct MainTabView: View {
    @ObservedObject var communitiesViewModel: CommunitiesViewModel
    @ObservedObject var chatsViewModel: ChatsViewModel
    @ObservedObject var connectViewModel: ConnectViewModel
    @ObservedObject var profileViewModel: ProfileViewModel

    let onChatSelected: (String) -> Void
    let onCommunitySelected: (String) -> Void
    let onSignOut: () -> Void

    var body: some View {
        TabView {
            PlaceholderScreen(title: "Communities", systemImage: "person.3")
                .tabItem {
                    Label("Communities", systemImage: "person.3")
                }

            PlaceholderScreen(title: "Chats", systemImage: "bubble.left.and.bubble.right")
                .tabItem {
                    Label("Chats", systemImage: "bubble.left.and.bubble.right")
                }

            PlaceholderScreen(title: "Connect", systemImage: "link")
                .tabItem {
                    Label("Connect", systemImage: "link")
                }

            ProfileView(viewModel: profileViewModel, onSignOut: onSignOut)
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
        }
    }
}
