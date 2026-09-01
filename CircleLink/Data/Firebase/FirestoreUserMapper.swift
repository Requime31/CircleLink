import FirebaseFirestore
import Foundation

enum FirestoreUserMapper {
    static func user(from document: DocumentSnapshot) throws -> User {
        user(id: document.documentID, data: document.data() ?? [:])
    }

    static func user(
        id: String,
        data: [String: Any],
        referenceDate: Date = Date(),
        calendar: Calendar = AgeCalculator.persistedCalendar,
        timeZone: TimeZone = AgeCalculator.persistedTimeZone
    ) -> User {
        let aboutMe = (data["aboutMe"] as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let birthDate = birthDate(from: data)

        let deletionRequestedAt = (data["deletionRequestedAt"] as? Timestamp)?.dateValue()
        return User(
            id: id,
            displayName: data["displayName"] as? String ?? "",
            avatarURL: (data["avatarURL"] as? String).flatMap(URL.init(string:)),
            avatarBase64: data["avatarBase64"] as? String,
            interests: data["interests"] as? [String] ?? [],
            birthDate: birthDate,
            age: age(
                from: data,
                birthDate: birthDate,
                referenceDate: referenceDate,
                calendar: calendar,
                timeZone: timeZone
            ),
            aboutMe: aboutMe,
            ageConfirmedAt: (data["ageConfirmedAt"] as? Timestamp)?.dateValue(),
            accountState: AccountState(rawValue: data["accountState"] as? String ?? "") ?? .active,
            deletionRequestedAt: deletionRequestedAt,
            scheduledDeletionAt: deletionRequestedAt.flatMap(AccountDeletionPolicy.scheduledDeletionDate)
        )
    }

    static func birthDate(from data: [String: Any]) -> Date? {
        (data["birthDate"] as? Timestamp)?.dateValue()
    }

    static func age(
        from data: [String: Any],
        birthDate: Date? = nil,
        referenceDate: Date = Date(),
        calendar: Calendar = AgeCalculator.persistedCalendar,
        timeZone: TimeZone = AgeCalculator.persistedTimeZone
    ) -> Int? {
        if data.keys.contains("birthDate"), !(data["birthDate"] is NSNull) {
            guard let birthDate else { return nil }
            let calculated = AgeCalculator.completedYears(
                since: birthDate,
                at: referenceDate,
                calendar: calendar,
                timeZone: timeZone
            )
            return (18...120).contains(calculated) ? calculated : nil
        }

        // Firestore numbers often arrive as `NSNumber`; plain `as? Int` can fail.
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

    static func ageConfirmationData(
        birthDate: Date,
        confirmedAt: Date,
        ageReferenceDate: Date? = nil,
        calendar: Calendar = AgeCalculator.persistedCalendar,
        timeZone: TimeZone = AgeCalculator.persistedTimeZone
    ) -> (publicProfile: [String: Any], privateAccount: [String: Any]) {
        let age = AgeCalculator.completedYears(
            since: birthDate,
            at: ageReferenceDate ?? confirmedAt,
            calendar: calendar,
            timeZone: timeZone
        )
        return (
            publicProfile: [
                "age": age,
                "ageConfirmedAt": FieldValue.serverTimestamp()
            ],
            privateAccount: [
                "birthDate": Timestamp(date: birthDate)
            ]
        )
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
            "accountState": AccountState.active.rawValue,
            "createdAt": FieldValue.serverTimestamp()
        ]
    }
}
