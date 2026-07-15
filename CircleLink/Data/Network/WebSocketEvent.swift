import Foundation

/// JSON event protocol for WebSocket communication (MVP events only).
enum WebSocketEvent: Codable, Equatable, Sendable {
    // MARK: - Client → Server

    case auth(token: String)
    case join(chatId: String)
    case leave(chatId: String)
    case message(chatId: String, text: String, clientMessageId: String)

    // MARK: - Server → Client

    case messageNew(
        chatId: String,
        messageId: String,
        senderId: String,
        text: String,
        createdAt: String
    )
    case error(code: String)

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case type
        case token
        case chatId
        case text
        case clientMessageId
        case messageId
        case senderId
        case createdAt
        case code
    }

    private enum EventType: String, Codable {
        case auth
        case join
        case leave
        case message
        case messageNew = "message.new"
        case error
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(EventType.self, forKey: .type)

        switch type {
        case .auth:
            self = .auth(token: try container.decode(String.self, forKey: .token))
        case .join:
            self = .join(chatId: try container.decode(String.self, forKey: .chatId))
        case .leave:
            self = .leave(chatId: try container.decode(String.self, forKey: .chatId))
        case .message:
            self = .message(
                chatId: try container.decode(String.self, forKey: .chatId),
                text: try container.decode(String.self, forKey: .text),
                clientMessageId: try container.decode(String.self, forKey: .clientMessageId)
            )
        case .messageNew:
            self = .messageNew(
                chatId: try container.decode(String.self, forKey: .chatId),
                messageId: try container.decode(String.self, forKey: .messageId),
                senderId: try container.decode(String.self, forKey: .senderId),
                text: try container.decode(String.self, forKey: .text),
                createdAt: try container.decode(String.self, forKey: .createdAt)
            )
        case .error:
            self = .error(code: try container.decode(String.self, forKey: .code))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case let .auth(token):
            try container.encode(EventType.auth, forKey: .type)
            try container.encode(token, forKey: .token)
        case let .join(chatId):
            try container.encode(EventType.join, forKey: .type)
            try container.encode(chatId, forKey: .chatId)
        case let .leave(chatId):
            try container.encode(EventType.leave, forKey: .type)
            try container.encode(chatId, forKey: .chatId)
        case let .message(chatId, text, clientMessageId):
            try container.encode(EventType.message, forKey: .type)
            try container.encode(chatId, forKey: .chatId)
            try container.encode(text, forKey: .text)
            try container.encode(clientMessageId, forKey: .clientMessageId)
        case let .messageNew(chatId, messageId, senderId, text, createdAt):
            try container.encode(EventType.messageNew, forKey: .type)
            try container.encode(chatId, forKey: .chatId)
            try container.encode(messageId, forKey: .messageId)
            try container.encode(senderId, forKey: .senderId)
            try container.encode(text, forKey: .text)
            try container.encode(createdAt, forKey: .createdAt)
        case let .error(code):
            try container.encode(EventType.error, forKey: .type)
            try container.encode(code, forKey: .code)
        }
    }
}
