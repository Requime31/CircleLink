import Foundation

/// Resolves the other participant from a deterministic direct-chat id (`uidA_uidB`).
nonisolated enum DirectChatPeer {
    static func peerUserId(chatId: String, currentUserId: String) -> String? {
        guard !chatId.hasPrefix("group_") else { return nil }

        let prefix = currentUserId + "_"
        if chatId.hasPrefix(prefix) {
            let peer = String(chatId.dropFirst(prefix.count))
            return peer.isEmpty ? nil : peer
        }

        let suffix = "_" + currentUserId
        if chatId.hasSuffix(suffix) {
            let peer = String(chatId.dropLast(suffix.count))
            return peer.isEmpty ? nil : peer
        }

        return nil
    }
}
