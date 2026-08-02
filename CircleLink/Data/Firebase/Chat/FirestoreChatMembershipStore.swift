import FirebaseFirestore
import Foundation

/// Direct/group chat creation and leave.
final class FirestoreChatMembershipStore: @unchecked Sendable {
    private let support: FirestoreChatSupport

    init(support: FirestoreChatSupport) {
        self.support = support
    }

    func createDirectChat(with userId: String) async throws -> String {
        let currentUserId = try support.requireCurrentUserId()

        guard currentUserId != userId else {
            throw FirestoreChatError.invalidPeer
        }

        let chatId = FirestoreChatMapper.directChatId(userIdA: currentUserId, userIdB: userId)
        let chatRef = support.db.collection(support.chatsCollection).document(chatId)
        let existing = try await chatRef.getDocument()

        if existing.exists {
            try await support.ensureChatRefsExist(
                chatId: chatId,
                participantIds: [currentUserId, userId],
                lastMessageText: existing.data()?["lastMessageText"] as? String,
                lastMessageAt: (existing.data()?["lastMessageAt"] as? Timestamp)?.dateValue() ?? Date()
            )
            return chatId
        }

        let peer = try await support.fetchUser(userId: userId)
        let peerName = peer?.displayName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let title = peerName.isEmpty ? "Chat" : peerName
        let now = Date()

        // Step 1: write chat first so security rules can see participantIds
        // when we write the peer's chatRef in step 2.
        try await chatRef.setData(
            [
                "type": ChatType.direct.rawValue,
                "title": title,
                "participantIds": [currentUserId, userId],
                "lastMessageText": NSNull(),
                "lastMessageAt": Timestamp(date: now),
                "unreadCount": 0
            ],
            merge: true
        )

        // Step 2: mirror refs for both participants (needed for chat list).
        let batch = support.db.batch()
        let refPayload = FirestoreChatMapper.chatRefData(lastMessageText: nil, lastMessageAt: now)
        for participantId in [currentUserId, userId] {
            let userChatRef = support.db.collection(support.usersCollection)
                .document(participantId)
                .collection(support.chatRefsCollection)
                .document(chatId)
            batch.setData(refPayload, forDocument: userChatRef, merge: true)
        }

        try await batch.commit()
        return chatId
    }

    func createGroupChat(communityId: String, participantIds: [String]) async throws -> String {
        let currentUserId = try support.requireCurrentUserId()

        let uniqueParticipants = Array(Set(participantIds)).sorted()
        guard !uniqueParticipants.isEmpty else {
            throw FirestoreChatError.emptyParticipants
        }

        guard uniqueParticipants.contains(currentUserId) else {
            throw FirestoreChatError.notCommunityMember
        }

        // Server-side membership check — don't trust client-only participant list.
        let memberDoc = try await support.db.collection(support.communitiesCollection)
            .document(communityId)
            .collection("members")
            .document(currentUserId)
            .getDocument()
        guard memberDoc.exists else {
            throw FirestoreChatError.notCommunityMember
        }

        let chatId = FirestoreChatMapper.groupChatId(communityId: communityId)
        let chatRef = support.db.collection(support.chatsCollection).document(chatId)
        let title = try await support.fetchCommunityName(communityId: communityId)
        let now = Date()

        // Write-first (merge + arrayUnion). Do not getDocument before join —
        // older rules denied reads for community members not yet in participantIds.
        try await chatRef.setData(
            [
                "type": ChatType.group.rawValue,
                "communityId": communityId,
                "title": title,
                "participantIds": FieldValue.arrayUnion(uniqueParticipants)
            ],
            merge: true
        )

        // Now a participant — safe to read for lastMessage seeding / chatRefs.
        let existing = try await chatRef.getDocument()
        let existingData = existing.data() ?? [:]
        let lastMessageText = existingData["lastMessageText"] as? String
        let lastMessageAt = (existingData["lastMessageAt"] as? Timestamp)?.dateValue()

        if lastMessageAt == nil {
            try await chatRef.setData(
                [
                    "lastMessageText": NSNull(),
                    "lastMessageAt": Timestamp(date: now)
                ],
                merge: true
            )
        }

        try await support.ensureChatRefsExist(
            chatId: chatId,
            participantIds: [currentUserId],
            lastMessageText: lastMessageText,
            lastMessageAt: lastMessageAt ?? now
        )
        return chatId
    }

    func leaveChat(chatId: String) async throws {
        let currentUserId = try support.requireCurrentUserId()

        let chatRef = support.db.collection(support.chatsCollection).document(chatId)

        // Remove from participantIds only when present. Non-participants (or missing
        // chat) still drop their chatRef so Leave Community can finish cleanly.
        do {
            let existing = try await chatRef.getDocument()
            if existing.exists {
                let participants = FirestoreChatMapper.participantIds(from: existing.data() ?? [:])
                if participants.contains(currentUserId) {
                    try await chatRef.setData(
                        ["participantIds": FieldValue.arrayRemove([currentUserId])],
                        merge: true
                    )
                }
            }
        } catch {
            // Unreadable chat — still clear local ref below.
        }

        try await support.db.collection(support.usersCollection)
            .document(currentUserId)
            .collection(support.chatRefsCollection)
            .document(chatId)
            .delete()
    }

    func leaveGroupChat(communityId: String) async throws {
        let chatId = FirestoreChatMapper.groupChatId(communityId: communityId)
        try await leaveChat(chatId: chatId)
    }
}
