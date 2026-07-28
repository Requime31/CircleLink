import Foundation

/// Push destination for opening a chat thread from the Chats tab.
struct ChatThreadRoute: Hashable {
    let chatId: String
    let title: String
    /// Group chats only — forwarded to Peer Profile for Connect.
    let communityId: String?
}

/// Push destination for Chat Info / Members (from inside a thread).
struct ChatInfoRoute: Hashable {
    let chatId: String
}

/// Push destination for the soft-hidden chats list.
struct HiddenChatsRoute: Hashable {}
