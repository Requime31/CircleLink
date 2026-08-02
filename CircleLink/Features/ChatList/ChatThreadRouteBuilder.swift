import Foundation

/// Builds `ChatThreadRoute` without reading chat-list ViewModel state.
nonisolated enum ChatThreadRouteBuilder {
    static let fallbackTitle = "Chat"

    static func make(
        chatId: String,
        title: String? = nil,
        communityId: String? = nil
    ) -> ChatThreadRoute {
        let trimmed = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let resolvedTitle = trimmed.isEmpty ? fallbackTitle : trimmed
        return ChatThreadRoute(
            chatId: chatId,
            title: resolvedTitle,
            communityId: communityId
        )
    }

    static func make(chatId: String, metadata: ChatThreadMetadata) -> ChatThreadRoute {
        make(
            chatId: chatId,
            title: metadata.title,
            communityId: metadata.communityId
        )
    }
}
