import Foundation

/// Shared send / retry status transitions (`sending` → `sent` / `failed`).
enum ChatSendStatusUpdater {
    /// - Parameter useClientIdAsMessageId: On successful send the item id becomes the client id
    ///   (matches previous ChatViewModel behavior so live merge stays aligned).
    static func applying(
        status: MessageStatus,
        to item: ChatMessageItem,
        useClientIdAsMessageId: Bool = false,
        mapper: ChatMessageMapper
    ) -> ChatMessageItem {
        let messageId = useClientIdAsMessageId ? item.clientMessageId : item.id
        let message = Message(
            id: messageId,
            chatId: item.chatId,
            senderId: item.senderId,
            text: item.text,
            imageURL: item.imageURL,
            createdAt: item.createdAt,
            clientMessageId: item.clientMessageId,
            status: status
        )
        return mapper.decorate(message: message, localImageData: item.localImageData)
    }
}
