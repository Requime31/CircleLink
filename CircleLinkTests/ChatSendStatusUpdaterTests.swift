import Foundation
import Testing
@testable import CircleLink

struct ChatSendStatusUpdaterTests {
    private let mapper = ChatMessageMapper(currentUserId: "user-1")

    @Test func marksSentUsingClientIdAsMessageId() {
        let optimistic = ChatMessageItem.optimistic(
            chatId: "chat-1",
            senderId: "user-1",
            text: "Ping",
            imageData: nil,
            clientMessageId: "client-9"
        )

        let sent = ChatSendStatusUpdater.applying(
            status: .sent,
            to: optimistic,
            useClientIdAsMessageId: true,
            mapper: mapper
        )

        #expect(sent.status == .sent)
        #expect(sent.id == "client-9")
        #expect(sent.clientMessageId == "client-9")
        #expect(sent.text == "Ping")
    }

    @Test func marksFailedKeepsExistingMessageId() {
        let optimistic = ChatMessageItem.optimistic(
            chatId: "chat-1",
            senderId: "user-1",
            text: "Ping",
            imageData: Data([0xAA]),
            clientMessageId: "client-9"
        )

        let failed = ChatSendStatusUpdater.applying(
            status: .failed,
            to: optimistic,
            mapper: mapper
        )

        #expect(failed.status == .failed)
        #expect(failed.id == optimistic.id)
        #expect(failed.localImageData == Data([0xAA]))
    }
}
