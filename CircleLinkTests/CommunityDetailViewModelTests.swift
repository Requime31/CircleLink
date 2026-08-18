import Foundation
import Testing
@testable import CircleLink

@MainActor
struct CommunityDetailViewModelTests {
    private func makeViewModel(
        community: MockCommunityRepository = MockCommunityRepository(),
        chat: MockChatRepository = MockChatRepository(),
        auth: MockAuthRepository = MockAuthRepository(currentUser: MockAuthRepository.sampleUser)
    ) -> (CommunityDetailViewModel, MockCommunityRepository, MockChatRepository) {
        let viewModel = CommunityDetailViewModel(
            communityId: "community-1",
            communityRepository: community,
            chatRepository: chat,
            authRepository: auth,
            communityPostRepository: StubCommunityPostRepository(),
            communityImageStorage: StubCommunityImageStorage(),
            userRepository: MockUserRepository()
        )
        return (viewModel, community, chat)
    }

    @Test func loadSetsCommunityMembersAndMembership() async {
        let (viewModel, _, _) = makeViewModel()

        await viewModel.load()

        #expect(viewModel.isMember == true)
        if case let .loaded(community) = viewModel.communityState {
            #expect(community.id == "community-1")
        } else {
            Issue.record("Expected loaded community")
        }
        if case let .loaded(members) = viewModel.membersState {
            #expect(members.contains { $0.id == "user-1" })
        } else {
            Issue.record("Expected loaded members")
        }
    }

    @Test func joinCallsRepositoryAndRefreshesMembership() async {
        let community = MockCommunityRepository()
        community.membersByCommunity["community-1"] = []
        let (viewModel, repo, _) = makeViewModel(community: community)

        await viewModel.load()
        #expect(viewModel.isMember == false)

        await viewModel.join()

        #expect(repo.joinCallCount == 1)
        #expect(repo.lastJoinedCommunityId == "community-1")
        #expect(viewModel.isMember == true)
    }

    @Test func leaveCallsLeaveGroupChatThenCommunityLeave() async {
        let callLog = MockCallLog()
        let community = MockCommunityRepository()
        community.callLog = callLog
        let chat = MockChatRepository()
        chat.callLog = callLog
        let (viewModel, _, _) = makeViewModel(community: community, chat: chat)
        await viewModel.load()
        #expect(viewModel.isMember == true)

        await viewModel.leave()

        #expect(chat.leaveGroupChatCallCount == 1)
        #expect(chat.lastLeaveGroupCommunityId == "community-1")
        #expect(community.leaveCallCount == 1)
        #expect(community.lastLeftCommunityId == "community-1")
        #expect(callLog.entries == ["leaveGroupChat", "community.leave"])
        #expect(viewModel.isMember == false)
    }

    @Test func leaveStopsWhenLeaveGroupChatFails() async {
        struct Boom: Error, LocalizedError {
            var errorDescription: String? { "Cannot leave chat" }
        }

        let chat = MockChatRepository()
        chat.leaveGroupChatError = Boom()
        let (viewModel, community, _) = makeViewModel(chat: chat)
        await viewModel.load()

        await viewModel.leave()

        #expect(chat.leaveGroupChatCallCount == 1)
        #expect(community.leaveCallCount == 0)
        #expect(viewModel.membershipErrorMessage == "Cannot leave chat")
        #expect(viewModel.isMember == true)
    }

    @Test func openGroupChatRequiresMembership() async {
        let community = MockCommunityRepository()
        community.membersByCommunity["community-1"] = []
        let (viewModel, _, chat) = makeViewModel(community: community)
        await viewModel.load()

        let result = await viewModel.openGroupChat()

        #expect(result == nil)
        #expect(chat.createGroupChatCallCount == 0)
        #expect(viewModel.membershipErrorMessage == "Join this community to open group chat.")
    }

    @Test func openGroupChatCreatesChatForMember() async {
        let chat = MockChatRepository()
        chat.createGroupChatResult = "group_community-1"
        let (viewModel, _, _) = makeViewModel(chat: chat)
        await viewModel.load()

        let result = await viewModel.openGroupChat()

        #expect(chat.createGroupChatCallCount == 1)
        #expect(result?.chatId == "group_community-1")
        #expect(result?.title == "Swift Devs")
    }
}
