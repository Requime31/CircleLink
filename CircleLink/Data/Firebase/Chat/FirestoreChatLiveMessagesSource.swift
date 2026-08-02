import FirebaseFirestore
import Foundation

/// Realtime message stream while a chat screen is open.
/// Listener is removed when the AsyncStream terminates (VM cancels observe Task).
final class FirestoreChatLiveMessagesSource: @unchecked Sendable {
    /// Recent window for the live listener — large enough to overlap `fetchMessages` pages
    /// and catch mid-flight sends without dumping the full history on first snapshot.
    private static let liveMessagesWindowSize = 50

    private let support: FirestoreChatSupport

    init(support: FirestoreChatSupport) {
        self.support = support
    }

    /// Live messages while the chat screen is open.
    /// Uses `limit(toLast:)` so the first snapshot is a recent window (overlaps history fetch),
    /// not the entire chat history — VM dedup + older-than-page filter handle the overlap.
    func observeLiveMessages(chatId: String) -> AsyncStream<Message> {
        let db = support.db
        let chatsCollection = support.chatsCollection
        let messagesCollection = support.messagesCollection

        return AsyncStream { continuation in
            let query = db.collection(chatsCollection)
                .document(chatId)
                .collection(messagesCollection)
                .order(by: "createdAt", descending: false)
                .limit(toLast: Self.liveMessagesWindowSize)

            let registration = query.addSnapshotListener { snapshot, error in
                if let error {
                    #if DEBUG
                    print("[FirestoreChatLiveMessagesSource] messages listener error: \(error.localizedDescription)")
                    #endif
                    return
                }

                guard let snapshot else { return }

                for change in snapshot.documentChanges {
                    guard change.type == .added || change.type == .modified else {
                        continue
                    }

                    do {
                        let message = try FirestoreChatMapper.message(
                            from: change.document,
                            chatId: chatId
                        )
                        continuation.yield(message)
                    } catch {
                        #if DEBUG
                        print("[FirestoreChatLiveMessagesSource] message map failed: \(error.localizedDescription)")
                        #endif
                    }
                }
            }

            continuation.onTermination = { _ in
                registration.remove()
            }
        }
    }
}
