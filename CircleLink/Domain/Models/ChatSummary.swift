import Foundation

struct ChatSummary: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let type: ChatType
    let title: String
    var lastMessageText: String?
    var lastMessageAt: Date?
    var unreadCount: Int
    /// Peer avatar for direct chats (resolved at fetch time).
    var avatarURL: URL?
    var avatarBase64: String?
}
