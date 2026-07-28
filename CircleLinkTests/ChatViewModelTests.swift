import Foundation
import Testing
@testable import CircleLink

@MainActor
struct ChatViewModelTests {
    @Test func loadInitialMessagesMapsAndSetsLoadedState() async {
        let repo = MockChatRepository()
        let now = Date()
        repo.messages = [
            Message(
                id: "m1",
                chatId: "chat-1",
                senderId: "peer-1",
                text: "Hello",
                imageURL: nil,
                createdAt: now.addingTimeInterval(-10),
                clientMessageId: "m1",
                status: .sent
            ),
            Message(
                id: "m2",
                chatId: "chat-1",
                senderId: "user-1",
                text: "Hi",
                imageURL: nil,
                createdAt: now,
                clientMessageId: "m2",
                status: .sent
            )
        ]

        let viewModel = ChatViewModel(
            chatId: "chat-1",
            currentUserId: "user-1",
            chatRepository: repo,
            chatTitle: "Peer"
        )

        await viewModel.loadInitialMessages()

        #expect(viewModel.chatTitle == "Peer")
        #expect(viewModel.messages.count == 2)
        #expect(viewModel.messages.first?.text == "Hi")
        if case .loaded = viewModel.loadState {
            // ok
        } else {
            Issue.record("Expected loaded state")
        }
    }

    @Test func sendInsertsOptimisticMessageThenMarksSent() async {
        let repo = MockChatRepository()
        let viewModel = ChatViewModel(
            chatId: "chat-1",
            currentUserId: "user-1",
            chatRepository: repo
        )
        await viewModel.loadInitialMessages()

        await viewModel.send(text: "Ping")

        #expect(repo.sentClientMessageIds.count == 1)
        #expect(viewModel.messages.first?.text == "Ping")
        #expect(viewModel.messages.first?.status == .sent)
        #expect(viewModel.messages.first?.isOutgoing == true)
    }

    @Test func sendIgnoresWhitespaceOnlyText() async {
        let repo = MockChatRepository()
        let viewModel = ChatViewModel(
            chatId: "chat-1",
            currentUserId: "user-1",
            chatRepository: repo
        )
        await viewModel.loadInitialMessages()

        await viewModel.send(text: "   ")

        #expect(repo.sentClientMessageIds.isEmpty)
        #expect(viewModel.messages.isEmpty)
    }

    @Test func sendFailureMarksMessageFailed() async {
        struct Boom: Error {}
        let repo = MockChatRepository()
        repo.sendError = Boom()
        let viewModel = ChatViewModel(
            chatId: "chat-1",
            currentUserId: "user-1",
            chatRepository: repo
        )
        await viewModel.loadInitialMessages()

        await viewModel.send(text: "Fail me")

        #expect(viewModel.messages.first?.status == .failed)
    }

    @Test func retryFailedMessageMarksSent() async throws {
        struct Boom: Error {}
        let repo = MockChatRepository()
        repo.sendError = Boom()
        let viewModel = ChatViewModel(
            chatId: "chat-1",
            currentUserId: "user-1",
            chatRepository: repo
        )
        await viewModel.loadInitialMessages()
        await viewModel.send(text: "Retry me")

        let clientId = try #require(viewModel.messages.first?.clientMessageId)
        #expect(viewModel.messages.first?.status == .failed)

        repo.sendError = nil
        await viewModel.retry(clientMessageId: clientId)

        #expect(viewModel.messages.first?.status == .sent)
        #expect(repo.sentClientMessageIds.count == 2)
    }

    @Test func liveMessageDeduplicatesByClientMessageId() async {
        let repo = MockChatRepository()
        let viewModel = ChatViewModel(
            chatId: "chat-1",
            currentUserId: "user-1",
            chatRepository: repo
        )
        await viewModel.loadInitialMessages()
        viewModel.onAppear()

        await viewModel.send(text: "Once")
        let clientId = repo.sentClientMessageIds[0]

        // Wait until the observe task has attached the stream.
        for _ in 0..<20 where repo.liveContinuation == nil {
            await Task.yield()
            try? await Task.sleep(nanoseconds: 10_000_000)
        }

        repo.liveContinuation?.yield(
            Message(
                id: "server-\(clientId)",
                chatId: "chat-1",
                senderId: "user-1",
                text: "Once",
                imageURL: nil,
                createdAt: Date(),
                clientMessageId: clientId,
                status: .sent
            )
        )

        var matchingCount = 0
        for _ in 0..<20 {
            matchingCount = viewModel.messages.filter {
                $0.clientMessageId == clientId || $0.text == "Once"
            }.count
            if matchingCount == 1 { break }
            await Task.yield()
            try? await Task.sleep(nanoseconds: 10_000_000)
        }

        #expect(matchingCount == 1)

        viewModel.onDisappear()
    }
}
