import Combine
import Foundation
import UserNotifications

/// Settings screen state: notifications toggle + About.
@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var notificationsEnabled = false
    @Published var showOpenSettingsAlert = false
    @Published private(set) var isUpdatingNotifications = false
    @Published private(set) var notificationHint: String?
    @Published private(set) var appVersionLabel = ""
    @Published var remindersEnabled = false
    @Published var reminderTime = ConnectReminderTime.defaultValue
    @Published private(set) var isUpdatingReminders = false
    @Published private(set) var reminderHint: String?
    @Published var showReminderSettingsAlert = false
    @Published var reminderError: String?
    @Published var showRatingUnavailableAlert = false

    private let pushHandler: PushNotificationHandler
    private let reminderScheduler: ReminderScheduling
    private let reminderPreferencesStore: ConnectReminderPreferencesStoring
    private let appRatingPresenter: AppRatingPresenting

    init(
        pushHandler: PushNotificationHandler,
        reminderScheduler: ReminderScheduling,
        reminderPreferencesStore: ConnectReminderPreferencesStoring,
        appRatingPresenter: AppRatingPresenting
    ) {
        self.pushHandler = pushHandler
        self.reminderScheduler = reminderScheduler
        self.reminderPreferencesStore = reminderPreferencesStore
        self.appRatingPresenter = appRatingPresenter
        let reminderPreferences = reminderPreferencesStore.preferences
        remindersEnabled = reminderPreferences.isEnabled
        reminderTime = reminderPreferences.time
        appVersionLabel = Self.makeVersionLabel()
    }

    func refresh() async {
        await refreshNotifications()
        await reconcileReminders()
    }

    private func refreshNotifications() async {
        let status = await pushHandler.authorizationStatus()
        let preference = pushHandler.isNotificationsEnabledPreference

        switch status {
        case .authorized, .provisional, .ephemeral:
            notificationsEnabled = preference
            notificationHint = preference ? nil : "Push delivery is paused."
        case .denied:
            notificationsEnabled = false
            notificationHint = "Turned off in iOS Settings."
        case .notDetermined:
            notificationsEnabled = false
            notificationHint = "Not decided yet."
        @unknown default:
            notificationsEnabled = false
            notificationHint = nil
        }
    }

    func setRemindersEnabled(_ enabled: Bool) async {
        guard !isUpdatingReminders, enabled != remindersEnabled else { return }
        isUpdatingReminders = true
        reminderError = nil
        defer { isUpdatingReminders = false }

        if !enabled {
            await reminderScheduler.removeReminder()
            saveReminderPreferences(isEnabled: false, time: reminderTime)
            remindersEnabled = false
            reminderHint = nil
            return
        }

        do {
            var status = await reminderScheduler.authorizationStatus()
            if status == .notDetermined {
                let granted = try await reminderScheduler.requestAuthorization()
                status = granted ? .authorized : .denied
            }

            guard status == .authorized else {
                await disableReminderForMissingPermission(showAlert: true)
                return
            }

            try await reminderScheduler.scheduleDaily(at: reminderTime)
            saveReminderPreferences(isEnabled: true, time: reminderTime)
            remindersEnabled = true
            reminderHint = nil
        } catch {
            await reminderScheduler.removeReminder()
            remindersEnabled = false
            saveReminderPreferences(isEnabled: false, time: reminderTime)
            reminderError = "Couldn’t schedule the reminder. Please try again."
        }
    }

    func setReminderTime(_ time: ConnectReminderTime) async {
        guard !isUpdatingReminders, time != reminderTime else { return }
        let previousTime = reminderTime
        isUpdatingReminders = true
        reminderError = nil
        defer { isUpdatingReminders = false }

        do {
            if remindersEnabled {
                guard await reminderScheduler.authorizationStatus() == .authorized else {
                    await disableReminderForMissingPermission(showAlert: true)
                    return
                }
                try await reminderScheduler.scheduleDaily(at: time)
            }
            reminderTime = time
            saveReminderPreferences(isEnabled: remindersEnabled, time: time)
        } catch {
            reminderTime = previousTime
            reminderError = "Couldn’t update the reminder time. Please try again."
        }
    }

    func reconcileReminders() async {
        let stored = reminderPreferencesStore.preferences
        reminderTime = stored.time

        guard stored.isEnabled else {
            remindersEnabled = false
            if await reminderScheduler.scheduledTime() != nil {
                await reminderScheduler.removeReminder()
            }
            reminderHint = nil
            return
        }

        guard await reminderScheduler.authorizationStatus() == .authorized else {
            await disableReminderForMissingPermission(showAlert: false)
            return
        }

        do {
            if await reminderScheduler.scheduledTime() != stored.time {
                try await reminderScheduler.scheduleDaily(at: stored.time)
            }
            remindersEnabled = true
            reminderHint = nil
        } catch {
            remindersEnabled = false
            reminderHint = "Couldn’t restore the daily reminder."
        }
    }

    private func disableReminderForMissingPermission(showAlert: Bool) async {
        await reminderScheduler.removeReminder()
        saveReminderPreferences(isEnabled: false, time: reminderTime)
        remindersEnabled = false
        reminderHint = "Turned off in iOS Settings."
        showReminderSettingsAlert = showAlert
    }

    private func saveReminderPreferences(isEnabled: Bool, time: ConnectReminderTime) {
        reminderPreferencesStore.save(.init(isEnabled: isEnabled, time: time))
    }

    func setNotificationsEnabled(_ enabled: Bool) async {
        isUpdatingNotifications = true
        defer { isUpdatingNotifications = false }

        let result = await pushHandler.setNotificationsEnabled(enabled)
        if result == .needsSystemSettings {
            notificationsEnabled = false
            showOpenSettingsAlert = true
        }
        await refresh()
    }

    func openSystemSettings() {
        pushHandler.openSystemSettings()
    }

    func requestAppRating() {
        showRatingUnavailableAlert = !appRatingPresenter.requestReview()
    }

    private static func makeVersionLabel() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "Version \(version) (\(build))"
    }
}
