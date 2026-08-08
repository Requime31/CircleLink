import Foundation

/// Full chat metadata for the Chat Info / Members screen.
struct ChatInfo: Equatable, Sendable, Identifiable {
    let id: String
    let type: ChatType
    let title: String
    /// Present for community group chats — used for Peer Profile Connect.
    let communityId: String?
    let participants: [User]
    /// From the current user's `chatRef` — push mute only.
    var isMuted: Bool
    /// Per-user history watermark. Messages at or before this are hidden for this user only.
    var clearedAt: Date?
}
