import Foundation
import Testing
@testable import CircleLink

struct ChatLiveMessageReconcilerTests {
    private let mapper = ChatMessageMapper(currentUserId: "user-1")
    private var reconciler: ChatLiveMessageReconciler {
        ChatLiveMessageReconciler(mapper: mapper)
    }

    private func message(
        id: String,
        text: String,
        senderId: String = "user-1",
        clientMessageId: String? = nil,
        createdAt: Date = Date(),
        status: MessageStatus = .sent
    ) -> Message {
        Message(
            id: id,
            chatId: "chat-1",
            senderId: senderId,
            text: text,
            imageURL: nil,
            createdAt: createdAt,
            clientMessageId: clientMessageId ?? id,
            status: status
        )
    }

    @Test func ignoresDuplicateServerMessageId() {
        let existing = mapper.decorate(message: message(id: "server-1", text: "Hi"))
        let state = ChatLiveMessageReconciler.State.rebuilt(from: [existing])

        let next = reconciler.apply(
            live: message(id: "server-1", text: "Hi again"),
            to: state
        )

        #expect(next.messages.count == 1)
        #expect(next.messages[0].text == "Hi")
    }

    @Test func mergesOptimisticByClientMessageIdAndKeepsLocalImage() {
        let clientId = "client-1"
        let optimistic = ChatMessageItem.optimistic(
            chatId: "chat-1",
            senderId: "user-1",
            text: "Photo",
            imageData: Data([0x01, 0x02]),
            clientMessageId: clientId
        )
        var state = ChatLiveMessageReconciler.State.rebuilt(from: [optimistic])

        let live = message(
            id: "server-\(clientId)",
            text: "Photo",
            clientMessageId: clientId
        )
        state = reconciler.apply(live: live, to: state)

        #expect(state.messages.count == 1)
        #expect(state.messages[0].id == "server-\(clientId)")
        #expect(state.messages[0].clientMessageId == clientId)
        #expect(state.messages[0].status == .sent)
        #expect(state.messages[0].localImageData == Data([0x01, 0x02]))
        #expect(state.knownMessageIds.contains("server-\(clientId)"))
    }

    @Test func insertsNewLiveMessageAtTop() {
        let older = mapper.decorate(
            message: message(id: "m1", text: "Old", createdAt: Date().addingTimeInterval(-60))
        )
        var state = ChatLiveMessageReconciler.State.rebuilt(from: [older])

        state = reconciler.apply(
            live: message(id: "m2", text: "New", senderId: "peer-1"),
            to: state
        )

        #expect(state.messages.count == 2)
        #expect(state.messages.first?.id == "m2")
        #expect(state.messages.first?.text == "New")
    }

    @Test func dropsLiveMessagesOlderThanCurrentPage() {
        let newest = mapper.decorate(
            message: message(id: "m-new", text: "New", createdAt: Date())
        )
        let oldestInPage = mapper.decorate(
            message: message(id: "m-old", text: "Page bottom", createdAt: Date().addingTimeInterval(-30))
        )
        // Newest-first list: first = newest, last = oldest loaded page boundary.
        var state = ChatLiveMessageReconciler.State.rebuilt(from: [newest, oldestInPage])

        state = reconciler.apply(
            live: message(
                id: "m-ancient",
                text: "Too old",
                createdAt: Date().addingTimeInterval(-120)
            ),
            to: state
        )

        #expect(state.messages.count == 2)
        #expect(!state.messages.contains { $0.id == "m-ancient" })
    }

    @Test func uniqueOlderFiltersAlreadyKnownIds() {
        let known = mapper.decorate(message: message(id: "m1", text: "Known", clientMessageId: "c1"))
        let state = ChatLiveMessageReconciler.State.rebuilt(from: [known])
        let candidates = [
            known,
            mapper.decorate(message: message(id: "m2", text: "Fresh", clientMessageId: "c2"))
        ]

        let unique = reconciler.uniqueOlder(candidates, given: state)

        #expect(unique.map(\.id) == ["m2"])
    }
}
