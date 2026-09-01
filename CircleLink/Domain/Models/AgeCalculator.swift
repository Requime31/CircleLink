import Foundation

enum AgeCalculator {
    /// Persisted date-only values use Gregorian UTC semantics so travel cannot change the birthday.
    static let persistedTimeZone = TimeZone.gmt
    static let persistedCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = persistedTimeZone
        return calendar
    }()

    /// Converts local date components into the canonical Firestore Timestamp representation.
    /// Noon avoids accidental day shifts when the value is later presented in nearby time zones.
    static func canonicalBirthDate(
        fromLocalDate date: Date,
        calendar: Calendar = Calendar(identifier: .gregorian),
        timeZone: TimeZone = .current
    ) -> Date? {
        var sourceCalendar = calendar
        sourceCalendar.timeZone = timeZone
        let components = sourceCalendar.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year, let month = components.month, let day = components.day else {
            return nil
        }

        return persistedCalendar.date(from: DateComponents(
            timeZone: persistedTimeZone,
            year: year,
            month: month,
            day: day,
            hour: 12
        ))
    }

    /// Converts a persisted UTC-noon birth date into a local DatePicker-safe value
    /// while preserving its Gregorian year/month/day components.
    static func localDate(
        fromPersistedBirthDate date: Date,
        calendar: Calendar = Calendar(identifier: .gregorian),
        timeZone: TimeZone = .current
    ) -> Date? {
        let components = persistedCalendar.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year, let month = components.month, let day = components.day else {
            return nil
        }

        var localCalendar = calendar
        localCalendar.timeZone = timeZone
        return localCalendar.date(from: DateComponents(
            timeZone: timeZone,
            year: year,
            month: month,
            day: day,
            hour: 12
        ))
    }

    /// Completed calendar years at a reference instant using explicit calendar semantics.
    /// Validation policy (future dates and supported age range) belongs to the calling flow.
    static func completedYears(
        since birthDate: Date,
        at referenceDate: Date,
        calendar: Calendar = .current,
        timeZone: TimeZone = .current
    ) -> Int {
        var calendar = calendar
        calendar.timeZone = timeZone

        let birthDay = calendar.startOfDay(for: birthDate)
        let referenceDay = calendar.startOfDay(for: referenceDate)
        return calendar.dateComponents([.year], from: birthDay, to: referenceDay).year ?? 0
    }
}
