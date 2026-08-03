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

    @Test func participantFailureKeepsMessagesUsableAndSurfacesWarning() async {
        struct ParticipantError: LocalizedError {
            var errorDescription: String? { "Participant details unavailable" }
        }

        let repo = MockChatRepository()
        repo.fetchChatInfoError = ParticipantError()
        let viewModel = ChatViewModel(
            chatId: "chat-1",
            currentUserId: "user-1",
            chatRepository: repo
        )

        await viewModel.loadInitialMessages()

        if case .loaded = viewModel.loadState {
            #expect(viewModel.participantLoadErrorMessage == "Participant details unavailable")
        } else {
            Issue.record("Participant decoration failure must not fail message history")
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

    @Test func cancelledInitialLoadDoesNotApplyStaleMessages() async {
        let repo = MockChatRepository()
        repo.messages = [
            Message(
                id: "stale",
                chatId: "chat-1",
                senderId: "peer-1",
                text: "Stale",
                imageURL: nil,
                createdAt: Date(),
                clientMessageId: "stale",
                status: .sent
            )
        ]
        repo.shouldHoldFetchMessages = true
        let viewModel = ChatViewModel(
            chatId: "chat-1",
            currentUserId: "user-1",
            chatRepository: repo
        )

        let loadTask = Task { await viewModel.loadInitialMessages() }
        await waitUntil { repo.isHoldingFetchMessages }

        viewModel.onDisappear()
        repo.releaseFetchMessagesHold()
        await loadTask.value

        #expect(viewModel.messages.isEmpty)
        if case .idle = viewModel.loadState {
            // Cancelled mid-load clears the spinner and does not apply stale rows.
        } else if case .error = viewModel.loadState {
            Issue.record("Cancellation should not surface as error")
        } else if case .loading = viewModel.loadState {
            Issue.record("Cancelled load should not leave stuck loading")
        } else {
            Issue.record("Unexpected loaded state after cancel")
        }
    }

    @Test func retryIgnoresDuplicateWhileInFlight() async throws {
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
        repo.shouldHoldSend = true
        let firstRetry = Task { await viewModel.retry(clientMessageId: clientId) }
        await waitUntil { repo.isHoldingSend }

        await viewModel.retry(clientMessageId: clientId)
        #expect(repo.sentClientMessageIds.count == 2)

        repo.releaseSendHold()
        await firstRetry.value
        #expect(repo.sentClientMessageIds.count == 2)
        #expect(viewModel.messages.first?.status == .sent)
    }

    private func waitUntil(_ condition: @MainActor () -> Bool) async {
        for _ in 0..<200 {
            if condition() { return }
            await Task.yield()
        }
    }
}
