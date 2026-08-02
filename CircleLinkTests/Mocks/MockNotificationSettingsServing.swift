import Foundation
import UserNotifications
@testable import CircleLink

@MainActor
final class MockNotificationSettingsServing: NotificationSettingsServing {
    var isNotificationsEnabledPreference = true
    var authorizationStatusResult: UNAuthorizationStatus = .authorized
    var setNotificationsEnabledResult: NotificationsToggleResult = .enabled
    var openSystemSettingsCallCount = 0
    var setNotificationsEnabledCallCount = 0
    var lastSetNotificationsEnabledValue: Bool?
    var authorizationStatusCallCount = 0

    func authorizationStatus() async -> UNAuthorizationStatus {
        authorizationStatusCallCount += 1
        return authorizationStatusResult
    }

    func setNotificationsEnabled(_ enabled: Bool) async -> NotificationsToggleResult {
        setNotificationsEnabledCallCount += 1
        lastSetNotificationsEnabledValue = enabled
        if case .enabled = setNotificationsEnabledResult {
            isNotificationsEnabledPreference = enabled
        } else if case .disabled = setNotificationsEnabledResult {
            isNotificationsEnabledPreference = false
        }
        return setNotificationsEnabledResult
    }

    func openSystemSettings() {
        openSystemSettingsCallCount += 1
    }
}
