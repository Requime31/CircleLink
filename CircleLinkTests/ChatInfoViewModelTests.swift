import Foundation
import Testing
@testable import CircleLink

@MainActor
struct ChatInfoViewModelTests {
    @Test func loadIncludesMuteAndParticipants() async {
        let repo = MockChatRepository()
        repo.chatInfoType = .group
        repo.isMutedByChatId["chat-1"] = true
        repo.chatInfoParticipants = [
            MockAuthRepository.sampleUser,
            User(
                id: "peer-1",
                displayName: "Alex",
                avatarURL: nil,
                avatarBase64: nil,
                interests: [],
                ageConfirmedAt: Date()
            )
        ]

        let viewModel = ChatInfoViewModel(
            chatId: "chat-1",
            currentUserId: "user-1",
            chatRepository: repo
        )
        viewModel.load()
        await waitForLoaded(viewModel)

        guard case let .loaded(info) = viewModel.state else {
            Issue.record("Expected loaded")
            return
        }
        #expect(info.isMuted == true)
        #expect(info.participants.count == 2)
        #expect(viewModel.displayParticipants(from: info).count == 2)
    }

    @Test func setMutedUpdatesStateAndRepository() async {
        let repo = MockChatRepository()
        let viewModel = ChatInfoViewModel(
            chatId: "chat-1",
            currentUserId: "user-1",
            chatRepository: repo
        )
        viewModel.load()
        await waitForLoaded(viewModel)

        await viewModel.setMuted(true)

        #expect(repo.setMutedCallCount == 1)
        if case let .loaded(info) = viewModel.state {
            #expect(info.isMuted == true)
        } else {
            Issue.record("Expected loaded after mute")
        }
    }

    @Test func clearHistorySetsWatermark() async {
        let repo = MockChatRepository()
        let viewModel = ChatInfoViewModel(
            chatId: "chat-1",
            currentUserId: "user-1",
            chatRepository: repo
        )
        viewModel.load()
        await waitForLoaded(viewModel)

        let success = await viewModel.clearHistory()

        #expect(success)
        #expect(repo.clearHistoryCallCount == 1)
        #expect(repo.clearedAtByChatId["chat-1"] != nil)
        if case let .loaded(info) = viewModel.state {
            #expect(info.clearedAt != nil)
        } else {
            Issue.record("Expected loaded after clear")
        }
    }

    @Test func deleteDirectChatSucceeds() async {
        let repo = MockChatRepository()
        let viewModel = ChatInfoViewModel(
            chatId: "chat-1",
            currentUserId: "user-1",
            chatRepository: repo
        )
        viewModel.load()
        await waitForLoaded(viewModel)

        let success = await viewModel.deleteDirectChat()

        #expect(success)
        #expect(repo.deleteDirectChatCallCount == 1)
        #expect(repo.deleteDirectChatIds == ["chat-1"])
    }

    @Test func hideChatSucceeds() async {
        let repo = MockChatRepository()
        let viewModel = ChatInfoViewModel(
            chatId: "chat-1",
            currentUserId: "user-1",
            chatRepository: repo
        )
        viewModel.load()
        await waitForLoaded(viewModel)

        let success = await viewModel.hideChat()

        #expect(success)
        #expect(repo.hideChatCallCount == 1)
    }

    @Test func fetchMessagesRespectsClearedAt() async {
        let repo = MockChatRepository()
        let now = Date()
        repo.clearedAtByChatId["chat-1"] = now.addingTimeInterval(-5)
        repo.messages = [
            Message(
                id: "old",
                chatId: "chat-1",
                senderId: "peer-1",
                text: "Old",
                imageURL: nil,
                createdAt: now.addingTimeInterval(-60),
                clientMessageId: "old",
                status: .sent
            ),
            Message(
                id: "new",
                chatId: "chat-1",
                senderId: "peer-1",
                text: "New",
                imageURL: nil,
                createdAt: now,
                clientMessageId: "new",
                status: .sent
            )
        ]

        let fetched = try? await repo.fetchMessages(chatId: "chat-1", limit: 20, before: nil)
        #expect(fetched?.count == 1)
        #expect(fetched?.first?.id == "new")
    }

    @Test func messagePaginationDoesNotSkipEqualTimestamps() async throws {
        let repo = MockChatRepository()
        let timestamp = Date()
        repo.messages = ["a", "b", "c"].map { id in
            Message(
                id: id,
                chatId: "chat-1",
                senderId: "peer-1",
                text: id,
                imageURL: nil,
                createdAt: timestamp,
                clientMessageId: id,
                status: .sent
            )
        }

        let firstPage = try await repo.fetchMessages(chatId: "chat-1", limit: 2, before: nil)
        let oldest = try #require(firstPage.first)
        let secondPage = try await repo.fetchMessages(
            chatId: "chat-1",
            limit: 2,
            before: MessagePageCursor(message: oldest)
        )

        #expect(Set(firstPage.map(\.id)) == ["b", "c"])
        #expect(secondPage.map(\.id) == ["a"])
    }

    private func waitForLoaded(_ viewModel: ChatInfoViewModel) async {
        for _ in 0..<40 {
            if case .loaded = viewModel.state { return }
            if case .error = viewModel.state { return }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
    }
}
