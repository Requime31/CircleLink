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
    /// Community id for group chats (Connect from Peer Profile).
    var communityId: String?
    /// Other user id for direct chats.
    var peerUserId: String?
    /// Per-user: suppress push only (chat stays in the list).
    var isMuted: Bool
}
