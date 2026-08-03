import FirebaseFirestore
import Foundation

/// Maps between Firestore `users/{id}` documents and Domain `User`.
/// Storage-shaped fields (`avatarBase64`) are decoded/encoded here — not in Features.
enum FirestoreUserMapper {
    static func document(from snapshot: DocumentSnapshot) -> FirestoreUserDocument {
        let data = snapshot.data() ?? [:]
        return FirestoreUserDocument(
            displayName: data["displayName"] as? String ?? "",
            avatarURLString: data["avatarURL"] as? String,
            avatarBase64: data["avatarBase64"] as? String,
            interests: data["interests"] as? [String] ?? [],
            ageConfirmedAt: (data["ageConfirmedAt"] as? Timestamp)?.dateValue()
        )
    }

    static func user(from snapshot: DocumentSnapshot) throws -> User {
        makeUser(id: snapshot.documentID, document: document(from: snapshot))
    }

    static func makeUser(id: String, document: FirestoreUserDocument) -> User {
        User(
            id: id,
            displayName: document.displayName,
            avatarURL: document.avatarURLString.flatMap(URL.init(string:)),
            avatarBase64: document.avatarBase64,
            interests: document.interests,
            ageConfirmedAt: document.ageConfirmedAt
        )
    }

    /// Profile fields written by `updateProfile`. Same keys/null semantics as before.
    static func profileWriteData(from user: User) -> [String: Any] {
        var data: [String: Any] = [
            "displayName": user.displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            "interests": user.interests
        ]

        if let avatarURL = user.avatarURL?.absoluteString {
            data["avatarURL"] = avatarURL
        } else {
            data["avatarURL"] = NSNull()
        }

        // Storage field: Spark workaround payload lives on the user document.
        if let avatarBase64 = user.avatarBase64 {
            data["avatarBase64"] = avatarBase64
        } else {
            data["avatarBase64"] = NSNull()
        }

        return data
    }

    static func defaultProfileData(displayName: String = "") -> [String: Any] {
        [
            "displayName": displayName,
            "avatarURL": NSNull(),
            "avatarBase64": NSNull(),
            "interests": [String](),
            "ageConfirmedAt": NSNull(),
            "createdAt": Timestamp(date: Date())
        ]
    }
}
