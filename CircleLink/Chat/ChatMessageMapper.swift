import Foundation

/// Pure mapping from domain `Message` → UI `ChatMessageItem` (labels / avatars).
struct ChatMessageMapper: Sendable {
    let currentUserId: String
    var participantsById: [String: User]

    init(currentUserId: String, participantsById: [String: User] = [:]) {
        self.currentUserId = currentUserId
        self.participantsById = participantsById
    }

    func decorate(message: Message, localImageData: Data? = nil) -> ChatMessageItem {
        let peer = participantsById[message.senderId]
        let label: String
        if message.senderId == currentUserId {
            label = "You"
        } else if let name = peer?.displayName, !name.isEmpty {
            label = name
        } else {
            label = "Member"
        }
        return ChatMessageItem(
            message: message,
            currentUserId: currentUserId,
            senderLabel: label,
            localImageData: localImageData,
            senderAvatarURL: peer?.avatarURL,
            senderAvatarBase64: peer?.avatarBase64
        )
    }

    /// Newest-first for the inverted chat list.
    func mapHistory(_ messages: [Message]) -> [ChatMessageItem] {
        messages
            .map { decorate(message: $0) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// Re-applies labels/avatars after participants load (keeps local image + status).
    func redecorate(_ items: [ChatMessageItem]) -> [ChatMessageItem] {
        items.map { item in
            decorate(
                message: Message(
                    id: item.id,
                    chatId: item.chatId,
                    senderId: item.senderId,
                    text: item.text,
                    imageURL: item.imageURL,
                    createdAt: item.createdAt,
                    clientMessageId: item.clientMessageId,
                    status: item.status
                ),
                localImageData: item.localImageData
            )
        }
    }
}
