import FirebaseAuth
import FirebaseFirestore
import Foundation

enum FirestoreModerationError: LocalizedError {
    case notAuthenticated
    case invalidTarget
    case cannotModerateSelf

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in."
        case .invalidTarget:
            return "Invalid user."
        case .cannotModerateSelf:
            return "You can’t report or block yourself."
        }
    }
}

final class FirestoreModerationRepository: ModerationRepository, @unchecked Sendable {
    private let reportsCollection = "reports"
    private let usersCollection = "users"
    private let blockedCollection = "blocked"

    private var db: Firestore { Firestore.firestore() }

    func reportUser(
        userId: String,
        reason: ReportReason,
        chatId: String?,
        communityId: String?
    ) async throws {
        guard let reporterId = Auth.auth().currentUser?.uid else {
            throw FirestoreModerationError.notAuthenticated
        }

        let reportedUserId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !reportedUserId.isEmpty else {
            throw FirestoreModerationError.invalidTarget
        }
        guard reporterId != reportedUserId else {
            throw FirestoreModerationError.cannotModerateSelf
        }

        var data: [String: Any] = [
            "reporterId": reporterId,
            "reportedUserId": reportedUserId,
            "reason": reason.rawValue,
            "createdAt": Timestamp(date: Date())
        ]

        if let chatId, !chatId.isEmpty {
            data["chatId"] = chatId
        }
        if let communityId, !communityId.isEmpty {
            data["communityId"] = communityId
        }

        _ = try await db.collection(reportsCollection).addDocument(data: data)
    }

    func blockUser(_ userId: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw FirestoreModerationError.notAuthenticated
        }

        let blockedUserId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !blockedUserId.isEmpty else {
            throw FirestoreModerationError.invalidTarget
        }
        guard currentUserId != blockedUserId else {
            throw FirestoreModerationError.cannotModerateSelf
        }

        try await db.collection(usersCollection)
            .document(currentUserId)
            .collection(blockedCollection)
            .document(blockedUserId)
            .setData(["createdAt": Timestamp(date: Date())], merge: true)
    }

    func unblockUser(_ userId: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw FirestoreModerationError.notAuthenticated
        }

        let blockedUserId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !blockedUserId.isEmpty else {
            throw FirestoreModerationError.invalidTarget
        }

        try await db.collection(usersCollection)
            .document(currentUserId)
            .collection(blockedCollection)
            .document(blockedUserId)
            .delete()
    }

    func fetchBlockedUserIds() async throws -> Set<String> {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw FirestoreModerationError.notAuthenticated
        }

        let snapshot = try await db.collection(usersCollection)
            .document(currentUserId)
            .collection(blockedCollection)
            .getDocuments()

        return Set(snapshot.documents.map(\.documentID))
    }
}
