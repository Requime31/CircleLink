import Foundation

/// UserDefaults keys for push permission / in-app notification preference.
struct PushNotificationPreferenceStore: Sendable {
    static let didRequestPermissionKey = "circlelink.didRequestPushPermission"
    /// In-app preference: when false, FCM token is cleared and not re-uploaded.
    static let notificationsEnabledKey = "circlelink.notificationsEnabled"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Defaults to `true` until the user turns notifications off in Settings.
    var isNotificationsEnabled: Bool {
        if defaults.object(forKey: Self.notificationsEnabledKey) == nil {
            return true
        }
        return defaults.bool(forKey: Self.notificationsEnabledKey)
    }

    func setNotificationsEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: Self.notificationsEnabledKey)
    }

    func markPermissionRequested() {
        defaults.set(true, forKey: Self.didRequestPermissionKey)
    }
}
