import FirebaseAuth
import FirebaseFirestore
import Foundation

/// Shared Firestore access + security-sensitive write helpers used by chat stores.
/// Owns collection names and helpers that more than one store needs.
final class FirestoreChatSupport: @unchecked Sendable {
    let chatsCollection = "chats"
    let messagesCollection = "messages"
    let usersCollection = "users"
    let communitiesCollection = "communities"
    let chatRefsCollection = "chatRefs"

    /// Firestore allows max 500 writes per batch — chunk to stay under the limit.
    private static let firestoreBatchLimit = 450

    var db: Firestore { Firestore.firestore() }

    func requireCurrentUserId() throws -> String {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FirestoreChatError.notAuthenticated
        }
        return userId
    }

    /// Ensures the current user is listed as a participant and has a chatRef.
    /// Does **not** set `type` / `title` — those are owned by createDirect/createGroup.
    /// Uses merge + arrayUnion only — never reads the chat doc first, because
    /// Firestore read rules deny non-participants on existing chats.
    func ensureChatAccess(chatId: String, senderId: String) async throws {
        let chatRef = db.collection(chatsCollection).document(chatId)
        try await chatRef.setData(
            [
                "participantIds": FieldValue.arrayUnion([senderId]),
                "lastMessageAt": Timestamp(date: Date())
            ],
            merge: true
        )

        let ref = db.collection(usersCollection)
            .document(senderId)
            .collection(chatRefsCollection)
            .document(chatId)
        try await ref.setData(
            FirestoreChatMapper.chatRefData(lastMessageText: nil, lastMessageAt: Date()),
            merge: true
        )
    }

    func resolveParticipantIds(chatId: String, fallback: [String]) async throws -> [String] {
        let chatDoc = try await db.collection(chatsCollection).document(chatId).getDocument()
        let ids = FirestoreChatMapper.participantIds(from: chatDoc.data() ?? [:])
        return ids.isEmpty ? fallback : ids
    }

    /// Firestore allows max 500 writes per batch — chunk to stay under the limit.
    func ensureChatRefsExist(
        chatId: String,
        participantIds: [String],
        lastMessageText: String?,
        lastMessageAt: Date
    ) async throws {
        let payload = FirestoreChatMapper.chatRefData(
            lastMessageText: lastMessageText,
            lastMessageAt: lastMessageAt
        )
        let uniqueIds = Array(Set(participantIds))
        var index = 0
        while index < uniqueIds.count {
            let end = min(index + Self.firestoreBatchLimit, uniqueIds.count)
            let chunk = uniqueIds[index..<end]
            let batch = db.batch()
            for participantId in chunk {
                let ref = db.collection(usersCollection)
                    .document(participantId)
                    .collection(chatRefsCollection)
                    .document(chatId)
                batch.setData(payload, forDocument: ref, merge: true)
            }
            try await batch.commit()
            index = end
        }
    }

    func fetchUser(userId: String) async throws -> User? {
        let document = try await db.collection(usersCollection).document(userId).getDocument()
        guard document.exists else { return nil }
        return try FirestoreUserMapper.user(from: document)
    }

    func fetchCommunityName(communityId: String) async throws -> String {
        let document = try await db.collection(communitiesCollection).document(communityId).getDocument()
        let name = (document.data()?["name"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let name, !name.isEmpty {
            return name
        }
        return "Group Chat"
    }
}
