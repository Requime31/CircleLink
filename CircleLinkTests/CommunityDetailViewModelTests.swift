import Foundation
import Testing
@testable import CircleLink

@MainActor
struct CommunityDetailViewModelTests {
    /// Keeps mocks + VM together without a 3-member tuple (SwiftLint `large_tuple`).
    private struct Fixture {
        let viewModel: CommunityDetailViewModel
        let community: MockCommunityRepository
        let chat: MockChatRepository
    }

    private func makeViewModel(
        community: MockCommunityRepository = MockCommunityRepository(),
        chat: MockChatRepository = MockChatRepository(),
        auth: MockAuthRepository = MockAuthRepository(currentUser: MockAuthRepository.sampleUser)
    ) -> Fixture {
        let viewModel = CommunityDetailViewModel(
            communityId: "community-1",
            communityRepository: community,
            authRepository: auth,
            leaveCommunity: LeaveCommunityUseCase(
                chatRepository: chat,
                communityRepository: community
            ),
            openCommunityChat: OpenCommunityChatUseCase(
                communityRepository: community,
                chatRepository: chat,
                authRepository: auth
            )
        )
        return Fixture(viewModel: viewModel, community: community, chat: chat)
    }

    @Test func loadSetsCommunityMembersAndMembership() async {
        let fixture = makeViewModel()
        let viewModel = fixture.viewModel

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
        let fixture = makeViewModel(community: community)
        let viewModel = fixture.viewModel
        let repo = fixture.community

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
        let fixture = makeViewModel(community: community, chat: chat)
        let viewModel = fixture.viewModel
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
        let fixture = makeViewModel(chat: chat)
        let viewModel = fixture.viewModel
        let community = fixture.community
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
        let fixture = makeViewModel(community: community)
        let viewModel = fixture.viewModel
        let chat = fixture.chat
        await viewModel.load()

        let result = await viewModel.openGroupChat()

        #expect(result == nil)
        #expect(chat.createGroupChatCallCount == 0)
        #expect(viewModel.membershipErrorMessage == "Join this community to open group chat.")
    }

    @Test func openGroupChatCreatesChatForMember() async {
        let chat = MockChatRepository()
        chat.createGroupChatResult = "group_community-1"
        let fixture = makeViewModel(chat: chat)
        let viewModel = fixture.viewModel
        await viewModel.load()

        let result = await viewModel.openGroupChat()

        #expect(chat.createGroupChatCallCount == 1)
        #expect(result?.chatId == "group_community-1")
        #expect(result?.title == "Swift Devs")
    }

    @Test func openGroupChatAppliesRefreshedMembersWhenMembershipRevoked() async {
        let community = MockCommunityRepository()
        // Initial load: user is a member (default fixture members).
        let fixture = makeViewModel(community: community)
        let viewModel = fixture.viewModel
        await viewModel.load()
        #expect(viewModel.isMember == true)

        // Refresh on open shows membership revoked.
        community.membersByCommunity["community-1"] = [
            User(
                id: "peer-1",
                displayName: "Peer",
                avatarURL: nil,
                avatarBase64: nil,
                interests: [],
                ageConfirmedAt: Date()
            )
        ]

        let result = await viewModel.openGroupChat()

        #expect(result == nil)
        #expect(viewModel.isMember == false)
        #expect(viewModel.membershipErrorMessage == "Only community members can open this group chat.")
        if case let .loaded(members) = viewModel.membersState {
            #expect(members.map(\.id) == ["peer-1"])
        } else {
            Issue.record("Expected refreshed members after revoked membership")
        }
        if case let .loaded(community) = viewModel.communityState {
            #expect(community.memberCount == 1)
        } else {
            Issue.record("Expected member count synced from refresh")
        }
    }
}
