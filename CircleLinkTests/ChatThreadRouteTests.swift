import Testing
@testable import CircleLink

struct ChatThreadRouteTests {
    @Test func directRouteNeverCarriesCommunityContext() {
        let route = ChatThreadRoute.direct(
            chatId: "peer-1_user-1",
            title: "Taylor"
        )

        #expect(route.chatId == "peer-1_user-1")
        #expect(route.title == "Taylor")
        #expect(route.communityId == nil)
    }

    @Test func groupRoutePreservesExplicitCommunityContext() {
        let route = ChatThreadRoute.group(
            chatId: "group_community-1",
            title: "Swift Devs",
            communityId: "community-1"
        )

        #expect(route.chatId == "group_community-1")
        #expect(route.communityId == "community-1")
    }
}
