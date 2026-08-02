import Foundation
import Testing
@testable import CircleLink

struct ChatMessageMapperTests {
    @Test func decorateLabelsCurrentUserAsYou() {
        let mapper = ChatMessageMapper(currentUserId: "user-1")
        let item = mapper.decorate(
            message: Message(
                id: "m1",
                chatId: "chat-1",
                senderId: "user-1",
                text: "Hi",
                imageURL: nil,
                createdAt: Date(),
                clientMessageId: "m1",
                status: .sent
            )
        )

        #expect(item.senderLabel == "You")
        #expect(item.isOutgoing == true)
    }

    @Test func decorateUsesPeerDisplayNameWhenPresent() {
        let peer = User(
            id: "peer-1",
            displayName: "Alex",
            avatarURL: nil,
            avatarBase64: nil,
            interests: [],
            ageConfirmedAt: Date()
        )
        let mapper = ChatMessageMapper(
            currentUserId: "user-1",
            participantsById: ["peer-1": peer]
        )
        let item = mapper.decorate(
            message: Message(
                id: "m1",
                chatId: "chat-1",
                senderId: "peer-1",
                text: "Hey",
                imageURL: nil,
                createdAt: Date(),
                clientMessageId: "m1",
                status: .sent
            )
        )

        #expect(item.senderLabel == "Alex")
        #expect(item.isOutgoing == false)
    }

    @Test func mapHistorySortsNewestFirst() {
        let mapper = ChatMessageMapper(currentUserId: "user-1")
        let now = Date()
        let items = mapper.mapHistory([
            Message(
                id: "old",
                chatId: "chat-1",
                senderId: "user-1",
                text: "Old",
                imageURL: nil,
                createdAt: now.addingTimeInterval(-10),
                clientMessageId: "old",
                status: .sent
            ),
            Message(
                id: "new",
                chatId: "chat-1",
                senderId: "user-1",
                text: "New",
                imageURL: nil,
                createdAt: now,
                clientMessageId: "new",
                status: .sent
            )
        ])

        #expect(items.map(\.id) == ["new", "old"])
    }
}
