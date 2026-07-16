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

        let data = FirestoreUserMapper.defaultProfileData()
        try await db.collection(usersCollection).document(userId).setData(data)
        let created = try await db.collection(usersCollection).document(userId).getDocument()
        return try FirestoreUserMapper.user(from: created)
    }

    func updateProfile(_ user: User) async throws {
        guard Auth.auth().currentUser?.uid == user.id else {
            throw FirestoreUserError.notAuthenticated
        }

        var data: [String: Any] = [
            "displayName": user.displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            "interests": user.interests
        ]

        if let avatarURL = user.avatarURL?.absoluteString {
            data["avatarURL"] = avatarURL
        } else {
            data["avatarURL"] = NSNull()
        }

        if let avatarBase64 = user.avatarBase64 {
            data["avatarBase64"] = avatarBase64
        } else {
            data["avatarBase64"] = NSNull()
        }

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
