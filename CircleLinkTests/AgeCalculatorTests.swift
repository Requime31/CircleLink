import Foundation
import Testing
@testable import CircleLink

struct AgeCalculatorTests {
    private var utc: TimeZone { TimeZone(secondsFromGMT: 0) ?? .current }

    @Test func birthdayBoundaryUsesCompletedCalendarYears() throws {
        let calendar = Calendar(identifier: .gregorian)
        let birthDate = try date(2000, 8, 20, calendar: calendar, timeZone: utc)

        let dayBefore = try date(2018, 8, 19, calendar: calendar, timeZone: utc)
        let birthday = try date(2018, 8, 20, calendar: calendar, timeZone: utc)
        let dayAfter = try date(2018, 8, 21, calendar: calendar, timeZone: utc)

        #expect(AgeCalculator.completedYears(since: birthDate, at: dayBefore, calendar: calendar, timeZone: utc) == 17)
        #expect(AgeCalculator.completedYears(since: birthDate, at: birthday, calendar: calendar, timeZone: utc) == 18)
        #expect(AgeCalculator.completedYears(since: birthDate, at: dayAfter, calendar: calendar, timeZone: utc) == 18)
    }

    @Test func leapDayCompletesYearOnFebruary28InNonLeapYear() throws {
        let calendar = Calendar(identifier: .gregorian)
        let birthDate = try date(2004, 2, 29, calendar: calendar, timeZone: utc)
        let dayBefore = try date(2022, 2, 27, calendar: calendar, timeZone: utc)
        let normalizedBirthday = try date(2022, 2, 28, calendar: calendar, timeZone: utc)

        #expect(AgeCalculator.completedYears(since: birthDate, at: dayBefore, calendar: calendar, timeZone: utc) == 17)
        #expect(AgeCalculator.completedYears(since: birthDate, at: normalizedBirthday, calendar: calendar, timeZone: utc) == 18)
    }

    @Test func timeZoneControlsDateOnlyBoundary() throws {
        let calendar = Calendar(identifier: .gregorian)
        let birthDate = try date(2000, 1, 1, hour: 12, calendar: calendar, timeZone: utc)
        let referenceDate = try date(2018, 1, 1, hour: 0, minute: 30, calendar: calendar, timeZone: utc)
        let losAngeles = try #require(TimeZone(identifier: "America/Los_Angeles"))

        #expect(AgeCalculator.completedYears(since: birthDate, at: referenceDate, calendar: calendar, timeZone: utc) == 18)
        #expect(AgeCalculator.completedYears(since: birthDate, at: referenceDate, calendar: calendar, timeZone: losAngeles) == 17)
    }

    @Test func injectedCalendarIsUsed() throws {
        let gregorian = Calendar(identifier: .gregorian)
        let buddhist = Calendar(identifier: .buddhist)
        let birthDate = try date(2000, 8, 20, calendar: gregorian, timeZone: utc)
        let referenceDate = try date(2018, 8, 20, calendar: gregorian, timeZone: utc)

        #expect(AgeCalculator.completedYears(since: birthDate, at: referenceDate, calendar: buddhist, timeZone: utc) == 18)
    }

    @Test func futureDateIsLeftForCallerValidation() throws {
        let calendar = Calendar(identifier: .gregorian)
        let birthDate = try date(2030, 1, 1, calendar: calendar, timeZone: utc)
        let referenceDate = try date(2029, 1, 1, calendar: calendar, timeZone: utc)

        #expect(AgeCalculator.completedYears(since: birthDate, at: referenceDate, calendar: calendar, timeZone: utc) == -1)
    }

    @Test func canonicalBirthDateIsStableAcrossSourceTimeZones() throws {
        let plusFourteen = try #require(TimeZone(secondsFromGMT: 14 * 60 * 60))
        let minusTwelve = try #require(TimeZone(secondsFromGMT: -12 * 60 * 60))
        let calendar = Calendar(identifier: .gregorian)
        let plusDate = try date(2000, 8, 20, calendar: calendar, timeZone: plusFourteen)
        let minusDate = try date(2000, 8, 20, calendar: calendar, timeZone: minusTwelve)

        let canonicalPlus = try #require(AgeCalculator.canonicalBirthDate(
            fromLocalDate: plusDate,
            calendar: calendar,
            timeZone: plusFourteen
        ))
        let canonicalMinus = try #require(AgeCalculator.canonicalBirthDate(
            fromLocalDate: minusDate,
            calendar: calendar,
            timeZone: minusTwelve
        ))
        let referenceDate = try date(
            2018,
            8,
            20,
            calendar: AgeCalculator.persistedCalendar,
            timeZone: AgeCalculator.persistedTimeZone
        )

        #expect(canonicalPlus == canonicalMinus)
        #expect(AgeCalculator.completedYears(
            since: canonicalPlus,
            at: referenceDate,
            calendar: AgeCalculator.persistedCalendar,
            timeZone: AgeCalculator.persistedTimeZone
        ) == 18)
    }

    @Test func persistedDateRoundTripsThroughLocalPickerDateAtUTCPlus14() throws {
        let plusFourteen = try #require(TimeZone(secondsFromGMT: 14 * 60 * 60))
        let calendar = Calendar(identifier: .gregorian)
        let originalLocalDate = try date(2000, 8, 20, calendar: calendar, timeZone: plusFourteen)
        let persisted = try #require(AgeCalculator.canonicalBirthDate(
            fromLocalDate: originalLocalDate,
            calendar: calendar,
            timeZone: plusFourteen
        ))
        let pickerDate = try #require(AgeCalculator.localDate(
            fromPersistedBirthDate: persisted,
            calendar: calendar,
            timeZone: plusFourteen
        ))
        let persistedAgain = try #require(AgeCalculator.canonicalBirthDate(
            fromLocalDate: pickerDate,
            calendar: calendar,
            timeZone: plusFourteen
        ))

        #expect(persistedAgain == persisted)
    }

    @Test func defaultCanonicalizationUsesGregorianComponents() throws {
        let localDate = try date(
            2000,
            8,
            20,
            calendar: Calendar(identifier: .gregorian),
            timeZone: utc
        )
        let persisted = try #require(AgeCalculator.canonicalBirthDate(
            fromLocalDate: localDate,
            timeZone: utc
        ))
        let components = AgeCalculator.persistedCalendar.dateComponents(
            [.year, .month, .day],
            from: persisted
        )

        #expect(components.year == 2000)
        #expect(components.month == 8)
        #expect(components.day == 20)
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        hour: Int = 12,
        minute: Int = 0,
        calendar: Calendar,
        timeZone: TimeZone
    ) throws -> Date {
        var calendar = calendar
        calendar.timeZone = timeZone
        return try #require(calendar.date(from: DateComponents(
            timeZone: timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )))
    }
}
