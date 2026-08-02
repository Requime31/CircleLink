import Foundation

/// Lightweight chat fields for navigation (open-chat / deep link).
/// Does not load participant profiles — use `ChatInfo` for the Chat Info screen.
nonisolated struct ChatThreadMetadata: Equatable, Sendable {
    let title: String
    let communityId: String?
}
