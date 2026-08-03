import FirebaseAuth
import FirebaseFirestore
import Foundation

enum FirestoreUserError: LocalizedError {
    case notAuthenticated
    case profileNotFound

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to access your profile."
        case .profileNotFound:
            return "User profile could not be found."
        }
    }
}

final class FirestoreUserRepository: UserRepository, @unchecked Sendable {
    private let usersCollection = "users"

    private var db: Firestore { Firestore.firestore() }

    func fetchProfile(userId: String) async throws -> User {
        let document = try await db.collection(usersCollection).document(userId).getDocument()

        if document.exists {
            return try FirestoreUserMapper.user(from: document)
        }

        // Bootstrap only the signed-in owner's missing doc (auth/onboarding).
        // Never create a profile when loading another user (peer sheet / Connect).
        guard Auth.auth().currentUser?.uid == userId else {
            throw FirestoreUserError.profileNotFound
        }

        let data = FirestoreUserMapper.defaultProfileData()
        try await db.collection(usersCollection).document(userId).setData(data)
        let created = try await db.collection(usersCollection).document(userId).getDocument()
        return try FirestoreUserMapper.user(from: created)
    }

    func fetchProfiles(userIds: [String]) async throws -> [String: User] {
        let unique = Array(Set(userIds.filter { !$0.isEmpty }))
        guard !unique.isEmpty else { return [:] }

        var result: [String: User] = [:]
        // Firestore `in` supports at most 30 values.
        let chunkSize = 30
        var start = 0
        while start < unique.count {
            let end = min(start + chunkSize, unique.count)
            let chunk = Array(unique[start..<end])
            let snapshot = try await db.collection(usersCollection)
                .whereField(FieldPath.documentID(), in: chunk)
                .getDocuments()

            for document in snapshot.documents where document.exists {
                if let user = try? FirestoreUserMapper.user(from: document) {
                    result[user.id] = user
                }
            }
            start = end
        }
        return result
    }

    func updateProfile(_ user: User) async throws {
        guard Auth.auth().currentUser?.uid == user.id else {
            throw FirestoreUserError.notAuthenticated
        }

        let data = FirestoreUserMapper.profileWriteData(from: user)
        let document = db.collection(usersCollection).document(user.id)
        let snapshot = try await document.getDocument()

        if snapshot.exists {
            try await document.updateData(data)
        } else {
            var createData = FirestoreUserMapper.defaultProfileData(displayName: user.displayName)
            createData["displayName"] = data["displayName"] as Any
            createData["interests"] = data["interests"] as Any
            createData["avatarURL"] = data["avatarURL"] as Any
            createData["avatarBase64"] = data["avatarBase64"] as Any
            try await document.setData(createData)
        }
    }

    func confirmAge() async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FirestoreUserError.notAuthenticated
        }

        try await db.collection(usersCollection).document(userId).updateData([
            "ageConfirmedAt": Timestamp(date: Date())
        ])
    }

    func updateFCMToken(_ token: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FirestoreUserError.notAuthenticated
        }

        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        try await db.collection(usersCollection).document(userId).setData(
            [
                "fcmToken": trimmed,
                "fcmTokenUpdatedAt": Timestamp(date: Date())
            ],
            merge: true
        )
    }

    func clearFCMToken() async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FirestoreUserError.notAuthenticated
        }

        try await db.collection(usersCollection).document(userId).setData(
            [
                "fcmToken": FieldValue.delete(),
                "fcmTokenUpdatedAt": FieldValue.delete()
            ],
            merge: true
        )
    }
}
