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
    let makePeerProfileSheet: (String, PeerProfileMode) -> PeerProfileSheet
    let makeSettingsViewModel: () -> SettingsViewModel
    let makeSupportViewModel: () -> SupportViewModel
    let onCommunitySelected: (String) -> Void
    let onOpenGroupChat: (String, String) -> Void
    let onSignOut: () -> Void
    let makeAccountDeletionViewModel: () -> AccountDeletionViewModel
    let makeBlockedPeopleViewModel: () -> BlockedPeopleViewModel

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
            .tag(AppCoordinator.MainTab.chats)

            ConnectView(
                viewModel: connectViewModel,
                makePeerProfileSheet: makePeerProfileSheet
            )
                .tabItem {
                    Label("Connect", systemImage: "link")
                }
                .tag(AppCoordinator.MainTab.connect)

            ProfileView(
                viewModel: profileViewModel,
                makeSettingsViewModel: makeSettingsViewModel,
                makeSupportViewModel: makeSupportViewModel,
                onSignOut: onSignOut,
                makeAccountDeletionViewModel: makeAccountDeletionViewModel,
                makeBlockedPeopleViewModel: makeBlockedPeopleViewModel
            )
            .tabItem {
                Label("Profile", systemImage: "person")
            }
            .tag(AppCoordinator.MainTab.profile)
        }
        .tint(CLColor.primary)
        .toolbarBackground(CLColor.canvas, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}
