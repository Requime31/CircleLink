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

    private let pushHandler: PushNotificationHandler

    init(pushHandler: PushNotificationHandler) {
        self.pushHandler = pushHandler
        appVersionLabel = Self.makeVersionLabel()
    }

    func refresh() async {
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

    private static func makeVersionLabel() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "Version \(version) (\(build))"
    }
}
