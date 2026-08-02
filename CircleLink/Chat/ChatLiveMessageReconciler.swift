import Foundation

/// Pure live-message apply + id-set tracking (no Firebase / MainActor).
struct ChatLiveMessageReconciler: Sendable {
    struct State: Equatable, Sendable {
        var messages: [ChatMessageItem]
        var knownMessageIds: Set<String>
        var knownClientMessageIds: Set<String>

        static let empty = Self(messages: [], knownMessageIds: [], knownClientMessageIds: [])

        static func rebuilt(from messages: [ChatMessageItem]) -> Self {
            Self(
                messages: messages,
                knownMessageIds: Set(messages.map(\.id)),
                knownClientMessageIds: Set(messages.map(\.clientMessageId))
            )
        }

        mutating func track(_ items: [ChatMessageItem]) {
            for item in items {
                knownMessageIds.insert(item.id)
                knownClientMessageIds.insert(item.clientMessageId)
            }
        }
    }

    let mapper: ChatMessageMapper

    /// Applies one live event. Returns updated state (may be unchanged when ignored).
    func apply(live message: Message, to state: State) -> State {
        var next = state
        let clientMessageId = message.clientMessageId ?? message.id

        if next.knownMessageIds.contains(message.id) {
            return next
        }

        if next.knownClientMessageIds.contains(clientMessageId) {
            if let index = next.messages.firstIndex(where: { $0.clientMessageId == clientMessageId }) {
                let existing = next.messages[index]
                next.messages[index] = mapper.decorate(
                    message: Message(
                        id: message.id,
                        chatId: message.chatId,
                        senderId: message.senderId,
                        text: message.text ?? existing.text,
                        imageURL: message.imageURL ?? existing.imageURL,
                        createdAt: message.createdAt,
                        clientMessageId: clientMessageId,
                        status: .sent
                    ),
                    localImageData: existing.localImageData
                )
                next.knownMessageIds.insert(message.id)
            }
            return next
        }

        // First snapshot can include messages older than the current page.
        // Those belong to pagination — do not insert them into the live list.
        if let oldestLoaded = next.messages.last?.createdAt, message.createdAt < oldestLoaded {
            return next
        }

        let item = mapper.decorate(message: message)
        next.messages.insert(item, at: 0)
        next.track([item])
        return next
    }

    /// Pagination helper: keep only items not already known.
    func uniqueOlder(_ items: [ChatMessageItem], given state: State) -> [ChatMessageItem] {
        items.filter { item in
            !state.knownMessageIds.contains(item.id)
                && !state.knownClientMessageIds.contains(item.clientMessageId)
        }
    }
}
