import Foundation
import UserNotifications

/// Result of toggling the in-app notifications preference from Settings.
enum NotificationsToggleResult: Equatable {
    case enabled
    case disabled
    /// System permission is denied — only iOS Settings can re-enable.
    case needsSystemSettings
}

/// Narrow settings-facing surface for notification preference / permission.
/// Keeps Features free of the full `PushNotificationHandler` lifecycle.
@MainActor
protocol NotificationSettingsServing: AnyObject {
    var isNotificationsEnabledPreference: Bool { get }
    func authorizationStatus() async -> UNAuthorizationStatus
    func setNotificationsEnabled(_ enabled: Bool) async -> NotificationsToggleResult
    func openSystemSettings()
}
