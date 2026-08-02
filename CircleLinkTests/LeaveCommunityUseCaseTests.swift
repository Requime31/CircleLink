import Foundation
import Testing
@testable import CircleLink

struct LeaveCommunityUseCaseTests {
    @Test func executeLeavesChatBeforeCommunity() async throws {
        let callLog = MockCallLog()
        let chat = MockChatRepository()
        chat.callLog = callLog
        let community = MockCommunityRepository()
        community.callLog = callLog

        let useCase = LeaveCommunityUseCase(
            chatRepository: chat,
            communityRepository: community
        )

        try await useCase.execute(communityId: "community-1")

        #expect(callLog.entries == ["leaveGroupChat", "community.leave"])
        #expect(chat.lastLeaveGroupCommunityId == "community-1")
        #expect(community.lastLeftCommunityId == "community-1")
    }

    @Test func executeStopsWhenLeaveGroupChatFails() async {
        struct Boom: Error {}
        let chat = MockChatRepository()
        chat.leaveGroupChatError = Boom()
        let community = MockCommunityRepository()

        let useCase = LeaveCommunityUseCase(
            chatRepository: chat,
            communityRepository: community
        )

        do {
            try await useCase.execute(communityId: "community-1")
            Issue.record("Expected throw")
        } catch {
            #expect(community.leaveCallCount == 0)
        }
    }
}
