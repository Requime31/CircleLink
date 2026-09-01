import Foundation
import UserNotifications

struct ConnectReminderTime: Equatable, Sendable {
    static let defaultValue = ConnectReminderTime(hour: 19, minute: 0)

    let hour: Int
    let minute: Int

    init(hour: Int, minute: Int) {
        self.hour = min(max(hour, 0), 23)
        self.minute = min(max(minute, 0), 59)
    }

    init(date: Date, calendar: Calendar = .autoupdatingCurrent) {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        self.init(hour: components.hour ?? Self.defaultValue.hour,
                  minute: components.minute ?? Self.defaultValue.minute)
    }

    func date(calendar: Calendar = .autoupdatingCurrent, now: Date = Date()) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now) ?? now
    }
}

enum ReminderAuthorizationStatus: Equatable, Sendable {
    case notDetermined, denied, authorized
}

@MainActor
protocol ReminderScheduling {
    func authorizationStatus() async -> ReminderAuthorizationStatus
    func requestAuthorization() async throws -> Bool
    func scheduledTime() async -> ConnectReminderTime?
    func scheduleDaily(at time: ConnectReminderTime) async throws
    func removeReminder() async
}

@MainActor
final class UserNotificationReminderScheduler: ReminderScheduling {
    static let identifier = "circlelink.connect.daily-reminder"

    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func authorizationStatus() async -> ReminderAuthorizationStatus {
        switch await center.notificationSettings().authorizationStatus {
        case .notDetermined: .notDetermined
        case .denied: .denied
        case .authorized, .provisional, .ephemeral: .authorized
        @unknown default: .denied
        }
    }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound])
    }

    func scheduledTime() async -> ConnectReminderTime? {
        let request = await center.pendingNotificationRequests()
            .first { $0.identifier == Self.identifier }
        guard let trigger = request?.trigger as? UNCalendarNotificationTrigger else { return nil }
        let components = trigger.dateComponents
        guard let hour = components.hour, let minute = components.minute else { return nil }
        return ConnectReminderTime(hour: hour, minute: minute)
    }

    func scheduleDaily(at time: ConnectReminderTime) async throws {
        let content = UNMutableNotificationContent()
        content.title = "Check Connect"
        content.body = "Take a moment to check your Connect activity and new connections."
        content.sound = .default

        var components = DateComponents()
        components.hour = time.hour
        components.minute = time.minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: Self.identifier, content: content, trigger: trigger)
        try await center.add(request)
    }

    func removeReminder() async {
        center.removePendingNotificationRequests(withIdentifiers: [Self.identifier])
    }
}

struct ConnectReminderPreferences: Equatable, Sendable {
    var isEnabled: Bool
    var time: ConnectReminderTime
}

@MainActor
protocol ConnectReminderPreferencesStoring {
    var preferences: ConnectReminderPreferences { get }
    func save(_ preferences: ConnectReminderPreferences)
}

@MainActor
final class UserDefaultsConnectReminderPreferencesStore: ConnectReminderPreferencesStoring {
    private enum Key {
        static let enabled = "circlelink.connectReminder.enabled"
        static let hour = "circlelink.connectReminder.hour"
        static let minute = "circlelink.connectReminder.minute"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var preferences: ConnectReminderPreferences {
        let hasTime = defaults.object(forKey: Key.hour) != nil
        let time = hasTime
            ? ConnectReminderTime(hour: defaults.integer(forKey: Key.hour),
                                  minute: defaults.integer(forKey: Key.minute))
            : .defaultValue
        return ConnectReminderPreferences(isEnabled: defaults.bool(forKey: Key.enabled), time: time)
    }

    func save(_ preferences: ConnectReminderPreferences) {
        defaults.set(preferences.isEnabled, forKey: Key.enabled)
        defaults.set(preferences.time.hour, forKey: Key.hour)
        defaults.set(preferences.time.minute, forKey: Key.minute)
    }
}
