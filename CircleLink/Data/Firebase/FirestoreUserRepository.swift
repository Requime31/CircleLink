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
            "displayName": user.displayName,
            "interests": user.interests
        ]

        if let avatarURL = user.avatarURL?.absoluteString {
            data["avatarURL"] = avatarURL
        } else {
            data["avatarURL"] = NSNull()
        }

        try await db.collection(usersCollection).document(user.id).updateData(data)
    }

    func confirmAge() async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FirestoreUserError.notAuthenticated
        }

        try await db.collection(usersCollection).document(userId).updateData([
            "ageConfirmedAt": Timestamp(date: Date())
        ])
    }
}
