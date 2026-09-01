import Foundation
import Testing
@testable import CircleLink

@MainActor
struct ChatViewModelTests {
    @Test func directPeerBlockSucceedsOnceAndCallsDismissHook() async {
        let moderation = MockModerationRepository()
        moderation.shouldSuspendBlock = true
        var callbackCount = 0
        let viewModel = ChatViewModel(
            chatId: "user-1_peer-1",
            currentUserId: "user-1",
            chatRepository: MockChatRepository(),
            chatTitle: "Peer",
            peerUserId: "peer-1",
            moderationRepository: moderation,
            onPeerBlocked: { callbackCount += 1 }
        )

        let first = Task { await viewModel.blockPeer() }
        await Task.yield()
        #expect(await viewModel.blockPeer() == false)
        moderation.resumeBlock()

        #expect(await first.value)
        #expect(moderation.blockCallCount == 1)
        #expect(callbackCount == 1)
        #expect(viewModel.didBlockPeer)
    }

    @Test func directPeerBlockFailureStaysRetryable() async {
        let moderation = MockModerationRepository()
        moderation.blockError = NSError(domain: "test", code: 3, userInfo: [NSLocalizedDescriptionKey: "No connection"])
        let viewModel = ChatViewModel(
            chatId: "user-1_peer-1",
            currentUserId: "user-1",
            chatRepository: MockChatRepository(),
            peerUserId: "peer-1",
            moderationRepository: moderation
        )

        #expect(await viewModel.blockPeer() == false)
        #expect(viewModel.moderationErrorMessage == "No connection")
        moderation.blockError = nil
        #expect(await viewModel.blockPeer())
    }

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

    @Test func lateInitialLoadDoesNotStartListenerAfterDisappear() async {
        let repo = MockChatRepository()
        repo.shouldSuspendMessageFetch = true
        let viewModel = ChatViewModel(
            chatId: "chat-1",
            currentUserId: "user-1",
            chatRepository: repo
        )

        viewModel.onAppear()
        let loadTask = Task { await viewModel.loadInitialMessages() }
        for _ in 0..<100 where repo.hasPendingMessageFetch == false {
            await Task.yield()
        }

        let didSuspendFetch = repo.hasPendingMessageFetch
        if !didSuspendFetch {
            repo.shouldSuspendMessageFetch = false
        }

        viewModel.onDisappear()
        repo.resumeMessageFetch()
        await loadTask.value
        await Task.yield()

        #expect(didSuspendFetch)
        #expect(repo.liveContinuation == nil)
    }

    @Test func livePeerProfileUpdateRedecoratesLoadedMessagesWithoutReloadingHistory() async throws {
        let chatRepository = MockChatRepository()
        chatRepository.chatInfoParticipants = [
            User(id: "peer-1", displayName: "Old name", avatarBase64: "old-avatar")
        ]
        chatRepository.messages = [
            Message(
                id: "message-1",
                chatId: "chat-1",
                senderId: "peer-1",
                text: "Hello",
                imageURL: nil,
                createdAt: Date(),
                clientMessageId: "message-1",
                status: .sent
            )
        ]
        let users = LiveProfileTestRepository()
        let viewModel = ChatViewModel(
            chatId: "chat-1",
            currentUserId: "user-1",
            chatRepository: chatRepository,
            chatTitle: "Old name",
            peerUserId: "peer-1",
            userRepository: users
        )

        await viewModel.loadInitialMessages()
        viewModel.onAppear()
        await users.waitUntilObserved()
        users.yield(User(id: "peer-1", displayName: "New name", avatarBase64: "new-avatar"))

        for _ in 0..<30 where viewModel.messages.first?.senderAvatarBase64 != "new-avatar" {
            await Task.yield()
        }

        #expect(viewModel.messages.count == 1)
        #expect(viewModel.messages.first?.text == "Hello")
        #expect(viewModel.messages.first?.senderLabel == "New name")
        #expect(viewModel.messages.first?.senderAvatarBase64 == "new-avatar")
        #expect(viewModel.chatTitle == "New name")
        viewModel.onDisappear()
    }

    @Test func peerProfileObservationStopsWhenChatDisappears() async {
        let users = LiveProfileTestRepository()
        let viewModel = ChatViewModel(
            chatId: "chat-1",
            currentUserId: "user-1",
            chatRepository: MockChatRepository(),
            chatTitle: "Original",
            peerUserId: "peer-1",
            userRepository: users
        )

        viewModel.onAppear()
        await users.waitUntilObserved()
        viewModel.onDisappear()
        await Task.yield()
        users.yield(User(id: "peer-1", displayName: "Too late"))
        await Task.yield()

        #expect(viewModel.chatTitle == "Original")
    }
}

private final class LiveProfileTestRepository: UserRepository, @unchecked Sendable {
    private let queue = DispatchQueue(label: "LiveProfileTestRepository")
    private var continuation: AsyncThrowingStream<User, Error>.Continuation?

    func waitUntilObserved() async {
        for _ in 0..<100 {
            let isObserved = queue.sync { continuation != nil }
            if isObserved { return }
            await Task.yield()
        }
    }

    func yield(_ user: User) {
        let streamContinuation = queue.sync { self.continuation }
        streamContinuation?.yield(user)
    }

    func observeProfiles(userIds: Set<String>) -> AsyncThrowingStream<User, Error> {
        AsyncThrowingStream { continuation in
            queue.sync {
                self.continuation = continuation
            }
        }
    }

    func fetchProfile(userId: String) async throws -> User { throw TestError.unsupported }
    func updateProfile(_ user: User) async throws { throw TestError.unsupported }
    func confirmAge(birthDate: Date) async throws { throw TestError.unsupported }
    func confirmAge() async throws { throw TestError.unsupported }
    func requestAccountDeletion(now: Date) async throws { throw TestError.unsupported }
    func restoreAccount() async throws { throw TestError.unsupported }
    func updateFCMToken(_ token: String) async throws { throw TestError.unsupported }
    func clearFCMToken() async throws { throw TestError.unsupported }

    private enum TestError: Error { case unsupported }
}
