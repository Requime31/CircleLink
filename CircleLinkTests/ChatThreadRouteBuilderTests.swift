import Foundation
import Testing
@testable import CircleLink

struct ChatThreadRouteBuilderTests {
    @Test func makeUsesProvidedTitleAndCommunityId() {
        let route = ChatThreadRouteBuilder.make(
            chatId: "chat-1",
            title: "Hiking",
            communityId: "community-1"
        )

        #expect(route.chatId == "chat-1")
        #expect(route.title == "Hiking")
        #expect(route.communityId == "community-1")
    }

    @Test func makeFallsBackWhenTitleMissingOrBlank() {
        let missing = ChatThreadRouteBuilder.make(chatId: "chat-1", title: nil, communityId: nil)
        let blank = ChatThreadRouteBuilder.make(chatId: "chat-1", title: "   ", communityId: "c-1")

        #expect(missing.title == ChatThreadRouteBuilder.fallbackTitle)
        #expect(missing.communityId == nil)
        #expect(blank.title == ChatThreadRouteBuilder.fallbackTitle)
        #expect(blank.communityId == "c-1")
    }

    @Test func makeFromMetadataMapsFields() {
        let metadata = ChatThreadMetadata(title: "Group", communityId: "community-9")
        let route = ChatThreadRouteBuilder.make(chatId: "chat-9", metadata: metadata)

        #expect(route.chatId == "chat-9")
        #expect(route.title == "Group")
        #expect(route.communityId == "community-9")
    }
}
