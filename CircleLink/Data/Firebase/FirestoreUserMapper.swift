import FirebaseFirestore
import Foundation

enum FirestoreUserMapper {
    static func user(from document: DocumentSnapshot) throws -> User {
        let data = document.data() ?? [:]
        return User(
            id: document.documentID,
            displayName: data["displayName"] as? String ?? "",
            avatarURL: (data["avatarURL"] as? String).flatMap(URL.init(string:)),
            interests: data["interests"] as? [String] ?? [],
            ageConfirmedAt: (data["ageConfirmedAt"] as? Timestamp)?.dateValue()
        )
    }

    static func defaultProfileData(displayName: String = "") -> [String: Any] {
        [
            "displayName": displayName,
            "avatarURL": NSNull(),
            "interests": [String](),
            "ageConfirmedAt": NSNull(),
            "createdAt": Timestamp(date: Date())
        ]
    }
}
