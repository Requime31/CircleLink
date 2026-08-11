import FirebaseFirestore
import Foundation

enum FirestoreUserMapper {
    static func user(from document: DocumentSnapshot) throws -> User {
        let data = document.data() ?? [:]
        let aboutMe = (data["aboutMe"] as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return User(
            id: document.documentID,
            displayName: data["displayName"] as? String ?? "",
            avatarURL: (data["avatarURL"] as? String).flatMap(URL.init(string:)),
            avatarBase64: data["avatarBase64"] as? String,
            interests: data["interests"] as? [String] ?? [],
            age: age(from: data),
            aboutMe: aboutMe,
            ageConfirmedAt: (data["ageConfirmedAt"] as? Timestamp)?.dateValue()
        )
    }

    /// Firestore numbers often arrive as `NSNumber`; plain `as? Int` can fail.
    static func age(from data: [String: Any]) -> Int? {
        let raw: Int?
        if let int = data["age"] as? Int {
            raw = int
        } else if let number = data["age"] as? NSNumber {
            raw = number.intValue
        } else {
            raw = nil
        }
        guard let raw, (18...120).contains(raw) else { return nil }
        return raw
    }

    static func defaultProfileData(displayName: String = "") -> [String: Any] {
        [
            "displayName": displayName,
            "avatarURL": NSNull(),
            "avatarBase64": NSNull(),
            "interests": [String](),
            "age": NSNull(),
            "aboutMe": "",
            "ageConfirmedAt": NSNull(),
            "createdAt": Timestamp(date: Date())
        ]
    }
}
