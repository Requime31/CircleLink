import SwiftUI

struct MainTabView: View {
    @Binding var selectedTab: AppCoordinator.MainTab
    @Binding var pendingChatRoute: ChatThreadRoute?
    let tabs: MainTabAssembly

    var body: some View {
        TabView(selection: $selectedTab) {
            tabs.communities.rootView
                .tabItem {
                    Label("Communities", systemImage: "person.3")
                }
                .accessibilityLabel("Communities tab")
                .tag(AppCoordinator.MainTab.communities)

            tabs.chats.rootView(pendingChatRoute: $pendingChatRoute)
                .tabItem {
                    Label("Chats", systemImage: "bubble.left.and.bubble.right")
                }
                .accessibilityLabel("Chats tab")
                .tag(AppCoordinator.MainTab.chats)

            tabs.connect.rootView
                .tabItem {
                    Label("Connect", systemImage: "link")
                }
                .accessibilityLabel("Connect tab")
                .tag(AppCoordinator.MainTab.connect)

            tabs.profile.rootView
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
                .accessibilityLabel("Profile tab")
                .tag(AppCoordinator.MainTab.profile)
        }
        .tint(CLColor.primary)
    }
}
