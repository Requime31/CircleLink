import Foundation
import Testing
@testable import CircleLink

@MainActor
struct PeerProfileViewModelTests {
    @Test func blockSuccessNotifiesOwnerAndCompletes() async {
        let moderation = MockModerationRepository()
        var blockedId: String?
        let viewModel = makeViewModel(
            mode: .social,
            moderationRepository: moderation,
            onBlocked: { blockedId = $0 }
        )
        await viewModel.load()

        #expect(await viewModel.block())
        #expect(viewModel.didBlock)
        #expect(blockedId == "peer-1")
    }

    @Test func blockFailureKeepsProfileAvailableForRetry() async {
        let moderation = MockModerationRepository()
        moderation.blockError = NSError(domain: "test", code: 2, userInfo: [NSLocalizedDescriptionKey: "Try again"])
        let viewModel = makeViewModel(mode: .social, moderationRepository: moderation)
        await viewModel.load()

        #expect(await viewModel.block() == false)
        #expect(viewModel.didBlock == false)
        #expect(viewModel.blockErrorMessage == "Try again")
    }

    @Test func likedYouLikeAcceptsAndCompletes() async {
        let connections = MockConnectionRepository()
        connections.incoming = [
            ConnectionRequest(
                id: "req-1",
                fromUserId: "peer-1",
                toUserId: "user-1",
                communityId: nil,
                status: .pending,
                createdAt: Date()
            )
        ]

        let viewModel = makeViewModel(
            mode: .likedYou(requestId: "req-1"),
            connectionRepository: connections
        )

        await viewModel.load()
        await viewModel.like()

        #expect(connections.acceptCallCount == 1)
        #expect(viewModel.didCompleteAction == true)
        #expect(viewModel.actionErrorMessage == nil)
    }

    @Test func likedYouSkipDeclinesAndCompletes() async {
        let connections = MockConnectionRepository()
        connections.incoming = [
            ConnectionRequest(
                id: "req-1",
                fromUserId: "peer-1",
                toUserId: "user-1",
                communityId: nil,
                status: .pending,
                createdAt: Date()
            )
        ]

        let viewModel = makeViewModel(
            mode: .likedYou(requestId: "req-1"),
            connectionRepository: connections
        )

        await viewModel.load()
        await viewModel.skip()

        #expect(connections.declineCallCount == 1)
        #expect(viewModel.didCompleteAction == true)
        #expect(viewModel.actionErrorMessage == nil)
    }

    @Test func likedYouLikeFailureKeepsSheetOpen() async {
        let connections = MockConnectionRepository()
        connections.respondError = NSError(
            domain: "test",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Network down"]
        )

        let viewModel = makeViewModel(
            mode: .likedYou(requestId: "req-1"),
            connectionRepository: connections
        )

        await viewModel.load()
        await viewModel.like()

        #expect(viewModel.didCompleteAction == false)
        #expect(viewModel.actionErrorMessage == "Network down")
    }

    @Test func socialLoadSetsMatchedRelationship() async {
        let connections = MockConnectionRepository()
        connections.matched = [
            ConnectionRequest(
                id: "a_b",
                fromUserId: "user-1",
                toUserId: "peer-1",
                communityId: nil,
                status: .accepted,
                createdAt: Date()
            )
        ]

        let viewModel = makeViewModel(
            mode: .social,
            connectionRepository: connections
        )

        await viewModel.load()

        #expect(viewModel.relationship == .matched)
        if case .loaded = viewModel.state {
            // ok
        } else {
            Issue.record("Expected loaded profile state")
        }
    }

    @Test func socialConnectSendsRequest() async {
        let connections = MockConnectionRepository()
        let viewModel = makeViewModel(
            mode: .social,
            connectionRepository: connections
        )

        await viewModel.load()
        await viewModel.connect()

        #expect(connections.sendConnectCallCount == 1)
        #expect(connections.lastSendConnectUserId == "peer-1")
        #expect(viewModel.relationship == .pending)
    }

    @Test func loadIncludesPeerPosts() async {
        let posts = MockProfilePostRepository()
        posts.posts = [
            ProfilePost(
                id: "post-1",
                authorId: "peer-1",
                text: "Hello from my profile",
                imageURL: nil,
                createdAt: Date()
            )
        ]
        let viewModel = makeViewModel(mode: .social, profilePostRepository: posts)

        await viewModel.load()

        #expect(viewModel.posts.map(\.id) == ["post-1"])
    }

    @Test func postFailureStillLoadsCoreProfile() async {
        let posts = MockProfilePostRepository()
        posts.fetchError = NSError(domain: "test", code: 2)
        let viewModel = makeViewModel(mode: .social, profilePostRepository: posts)

        await viewModel.load()

        if case .loaded = viewModel.state {
            #expect(viewModel.posts.isEmpty)
        } else {
            Issue.record("Expected profile to load when posts fail")
        }
    }

    @Test func matchedPeerCanOpenDirectChat() async {
        let connections = MockConnectionRepository()
        connections.matched = [
            ConnectionRequest(
                id: "match-1",
                fromUserId: "user-1",
                toUserId: "peer-1",
                communityId: nil,
                status: .accepted,
                createdAt: Date()
            )
        ]
        let chats = MockChatRepository()
        let viewModel = makeViewModel(
            mode: .social,
            connectionRepository: connections,
            chatRepository: chats
        )

        await viewModel.load()
        let route = await viewModel.openChat()

        #expect(route?.chatId == "direct-chat-1")
        #expect(chats.createDirectChatCallCount == 1)
    }

    private func makeViewModel(
        mode: PeerProfileMode,
        connectionRepository: MockConnectionRepository = MockConnectionRepository(),
        userRepository: MockUserRepository = MockUserRepository(),
        communityRepository: MockCommunityRepository = MockCommunityRepository(),
        profilePostRepository: MockProfilePostRepository = MockProfilePostRepository(),
        chatRepository: MockChatRepository = MockChatRepository(),
        moderationRepository: MockModerationRepository = MockModerationRepository(),
        onBlocked: @escaping (String) -> Void = { _ in }
    ) -> PeerProfileViewModel {
        PeerProfileViewModel(
            userId: "peer-1",
            mode: mode,
            userRepository: userRepository,
            connectionRepository: connectionRepository,
            communityRepository: communityRepository,
            profilePostRepository: profilePostRepository,
            chatRepository: chatRepository,
            moderationRepository: moderationRepository,
            onBlocked: onBlocked
        )
    }
}
