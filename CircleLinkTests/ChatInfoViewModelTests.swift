import Foundation
import Testing
@testable import CircleLink

@MainActor
struct ChatInfoViewModelTests {
    private let selfUser = MockAuthRepository.sampleUser
    private let peer = User(
        id: "peer-1",
        displayName: "Peer",
        avatarURL: nil,
        avatarBase64: nil,
        interests: ["Design", "Music", "Art"],
        ageConfirmedAt: Date()
    )

    @Test func loadSetsChatInfo() async {
        let repo = MockChatRepository()
        repo.chatInfos["chat-1"] = ChatInfo(
            id: "chat-1",
            type: .direct,
            title: "Peer",
            communityId: nil,
            participants: [selfUser, peer]
        )
        let viewModel = ChatInfoViewModel(
            chatId: "chat-1",
            currentUserId: selfUser.id,
            chatRepository: repo
        )

        viewModel.load()
        await waitUntilLoaded(viewModel)

        if case let .loaded(info) = viewModel.state {
            #expect(info.id == "chat-1")
            #expect(info.type == .direct)
            #expect(viewModel.navigationTitle == "Chat Info")
            #expect(viewModel.displayParticipants(from: info).map(\.id) == ["peer-1"])
        } else {
            Issue.record("Expected loaded chat info")
        }
    }

    @Test func leaveChatSucceeds() async {
        let repo = MockChatRepository()
        let viewModel = ChatInfoViewModel(
            chatId: "chat-1",
            currentUserId: selfUser.id,
            chatRepository: repo
        )

        let ok = await viewModel.leaveChat()

        #expect(ok)
        #expect(repo.leaveChatCallCount == 1)
        #expect(repo.lastLeaveChatId == "chat-1")
        #expect(viewModel.leaveErrorMessage == nil)
        #expect(!viewModel.isLeaving)
    }

    @Test func leaveChatIgnoresDuplicateWhileInFlight() async {
        let repo = MockChatRepository()
        // Leave has no hold hook; use rapid double-call — second should see isLeaving.
        // Make leave wait via organized-style hold isn't available; simulate with Task race
        // by starting leave and immediately calling again before defer clears.
        let viewModel = ChatInfoViewModel(
            chatId: "chat-1",
            currentUserId: selfUser.id,
            chatRepository: repo
        )

        async let first = viewModel.leaveChat()
        async let second = viewModel.leaveChat()
        let results = await (first, second)

        #expect(results.0 || results.1)
        #expect(!(results.0 && results.1))
        #expect(repo.leaveChatCallCount == 1)
        #expect(!viewModel.isLeaving)
    }

    @Test func cancelLoadDoesNotSurfaceError() async {
        let repo = MockChatRepository()
        repo.chatInfos["chat-1"] = ChatInfo(
            id: "chat-1",
            type: .direct,
            title: "Peer",
            communityId: nil,
            participants: [selfUser, peer]
        )
        let viewModel = ChatInfoViewModel(
            chatId: "chat-1",
            currentUserId: selfUser.id,
            chatRepository: repo
        )

        viewModel.load()
        viewModel.cancelLoad()
        await Task.yield()
        await Task.yield()

        if case .error = viewModel.state {
            Issue.record("Cancel should not surface as error")
        }
    }

    private func waitUntilLoaded(_ viewModel: ChatInfoViewModel) async {
        for _ in 0..<200 {
            if case .loaded = viewModel.state { return }
            if case .error = viewModel.state { return }
            await Task.yield()
        }
    }
}
