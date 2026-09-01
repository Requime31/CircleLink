import FirebaseFirestore
import Foundation
import Testing
@testable import CircleLink

struct FirestoreUserMapperTests {
    private var utc: TimeZone { TimeZone(secondsFromGMT: 0) ?? .current }

    @Test func birthDateConfirmationPayloadRoundTripsThroughMapper() throws {
        let calendar = Calendar(identifier: .gregorian)
        let birthDate = try date(1990, 8, 20, calendar: calendar)
        let confirmedAt = try date(2026, 8, 20, calendar: calendar)
        let payload = FirestoreUserMapper.ageConfirmationData(
            birthDate: birthDate,
            confirmedAt: confirmedAt,
            calendar: calendar,
            timeZone: utc
        )
        #expect(payload.publicProfile.keys.contains("birthDate") == false)
        #expect(payload.privateAccount.keys.contains("age") == false)
        #expect(payload.publicProfile["ageConfirmedAt"] is FieldValue)
        var combined = payload.publicProfile
        combined.merge(payload.privateAccount) { _, privateValue in privateValue }
        // Firestore resolves the server timestamp before the payload is read.
        combined["ageConfirmedAt"] = Timestamp(date: confirmedAt)

        let user = FirestoreUserMapper.user(
            id: "user-1",
            data: combined,
            referenceDate: confirmedAt,
            calendar: calendar,
            timeZone: utc
        )

        #expect(user.birthDate == birthDate)
        #expect(user.age == 36)
        #expect(user.ageConfirmedAt == confirmedAt)
    }

    @Test func defaultPublicProfileDoesNotContainBirthDate() {
        let data = FirestoreUserMapper.defaultProfileData()

        #expect(data.keys.contains("birthDate") == false)
        #expect(data["accountState"] as? String == AccountState.active.rawValue)
        #expect(data["createdAt"] is FieldValue)
    }

    @Test func absentBirthDateFallsBackToLegacyNSNumberAge() throws {
        let referenceDate = try date(2026, 8, 20)
        let user = FirestoreUserMapper.user(
            id: "legacy",
            data: ["age": NSNumber(value: 29)],
            referenceDate: referenceDate,
            timeZone: utc
        )

        #expect(user.birthDate == nil)
        #expect(user.age == 29)
    }

    @Test func nullBirthDateFallsBackToLegacyAge() throws {
        let referenceDate = try date(2026, 8, 20)
        let user = FirestoreUserMapper.user(
            id: "legacy",
            data: ["birthDate": NSNull(), "age": 42],
            referenceDate: referenceDate,
            timeZone: utc
        )

        #expect(user.birthDate == nil)
        #expect(user.age == 42)
    }

    @Test func invalidBirthDateDoesNotTrustLegacyAge() throws {
        let referenceDate = try date(2026, 8, 20)
        let user = FirestoreUserMapper.user(
            id: "invalid",
            data: ["birthDate": "not-a-timestamp", "age": 42],
            referenceDate: referenceDate,
            timeZone: utc
        )

        #expect(user.birthDate == nil)
        #expect(user.age == nil)
    }

    @Test func futureBirthDateDoesNotProducePublicAge() throws {
        let referenceDate = try date(2026, 8, 20)
        let futureDate = try date(2027, 8, 20)
        let user = FirestoreUserMapper.user(
            id: "future",
            data: ["birthDate": Timestamp(date: futureDate), "age": 42],
            referenceDate: referenceDate,
            timeZone: utc
        )

        #expect(user.birthDate == futureDate)
        #expect(user.age == nil)
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) throws -> Date {
        var calendar = calendar
        calendar.timeZone = utc
        return try #require(calendar.date(from: DateComponents(
            timeZone: utc,
            year: year,
            month: month,
            day: day,
            hour: 12
        )))
    }
}
