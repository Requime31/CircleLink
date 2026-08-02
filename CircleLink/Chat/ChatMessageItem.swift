import Foundation

struct ChatMessageItem: Equatable, Identifiable {
    let id: String
    let chatId: String
    let senderId: String
    let senderLabel: String
    let text: String?
    let imageURL: URL?
    let localImageData: Data?
    let createdAt: Date
    let clientMessageId: String
    let status: MessageStatus
    let isOutgoing: Bool
    let senderAvatarURL: URL?
    let senderAvatarBase64: String?

    init(
        message: Message,
        currentUserId: String,
        senderLabel: String = "Member",
        localImageData: Data? = nil,
        senderAvatarURL: URL? = nil,
        senderAvatarBase64: String? = nil
    ) {
        id = message.id
        chatId = message.chatId
        senderId = message.senderId
        self.senderLabel = message.senderId == currentUserId ? "You" : senderLabel
        text = message.text
        imageURL = message.imageURL
        self.localImageData = localImageData
        createdAt = message.createdAt
        clientMessageId = message.clientMessageId ?? message.id
        status = message.status
        isOutgoing = message.senderId == currentUserId
        self.senderAvatarURL = senderAvatarURL
        self.senderAvatarBase64 = senderAvatarBase64
    }

    static func optimistic(
        chatId: String,
        senderId: String,
        text: String?,
        imageData: Data?,
        clientMessageId: String
    ) -> Self {
        Self(
            message: Message(
                id: clientMessageId,
                chatId: chatId,
                senderId: senderId,
                text: text,
                imageURL: nil,
                createdAt: Date(),
                clientMessageId: clientMessageId,
                status: .sending
            ),
            currentUserId: senderId,
            senderLabel: "You",
            localImageData: imageData
        )
    }
}
