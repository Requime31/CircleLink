import FirebaseFirestore
import Foundation

enum FirestoreChatMapper {
    static func message(from document: DocumentSnapshot, chatId: String) throws -> Message {
        let data = document.data() ?? [:]
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()

        return Message(
            id: document.documentID,
            chatId: chatId,
            senderId: data["senderId"] as? String ?? "",
            text: data["text"] as? String,
            imageURL: (data["imageURL"] as? String).flatMap(URL.init(string:)),
            createdAt: createdAt,
            clientMessageId: data["clientMessageId"] as? String,
            status: MessageStatus(rawValue: data["status"] as? String ?? "") ?? .sent
        )
    }

    static func messageData(
        senderId: String,
        text: String?,
        imageURL: URL?,
        clientMessageId: String,
        createdAt: Date
    ) -> [String: Any] {
        var data: [String: Any] = [
            "senderId": senderId,
            "createdAt": Timestamp(date: createdAt),
            "clientMessageId": clientMessageId,
            "status": MessageStatus.sent.rawValue
        ]

        if let text, !text.isEmpty {
            data["text"] = text
        } else {
            data["text"] = NSNull()
        }

        if let imageURL {
            data["imageURL"] = imageURL.absoluteString
        } else {
            data["imageURL"] = NSNull()
        }

        return data
    }

    static func chatSummary(from document: DocumentSnapshot) throws -> ChatSummary {
        let data = document.data() ?? [:]
        let typeRaw = data["type"] as? String ?? ChatType.direct.rawValue

        return ChatSummary(
            id: document.documentID,
            type: ChatType(rawValue: typeRaw) ?? .direct,
            title: data["title"] as? String ?? "Chat",
            lastMessageText: data["lastMessageText"] as? String,
            lastMessageAt: (data["lastMessageAt"] as? Timestamp)?.dateValue(),
            unreadCount: data["unreadCount"] as? Int ?? 0
        )
    }
}
