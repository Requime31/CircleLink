import Foundation
import UIKit
import UserNotifications

/// Facade for push permission, FCM token lifecycle, and deep-link forwarding.
/// Navigation is forwarded to `AppCoordinator` via `onDeepLink` — never routes itself.
/// Conforms to `NotificationSettingsServing` for Settings UI (narrow surface).
@MainActor
final class PushNotificationHandler: NSObject, NotificationSettingsServing {
    private let preferences: PushNotificationPreferenceStore
    private let tokenRegistrar: FCMTokenRegistrar

    /// Set by AppCoordinator — only place that may navigate from a push.
    var onDeepLink: ((PushDeepLink) -> Void)?

    init(
        userRepository: UserRepository,
        authRepository: AuthRepository,
        defaults: UserDefaults = .standard
    ) {
        let preferences = PushNotificationPreferenceStore(defaults: defaults)
        self.preferences = preferences
        self.tokenRegistrar = FCMTokenRegistrar(
            userRepository: userRepository,
            authRepository: authRepository,
            preferences: preferences
        )
        super.init()
    }

    // MARK: - NotificationSettingsServing

    var isNotificationsEnabledPreference: Bool {
        preferences.isNotificationsEnabled
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Toggle from Settings. Off clears FCM so the push worker has nothing to send.
    func setNotificationsEnabled(_ enabled: Bool) async -> NotificationsToggleResult {
        if enabled {
            let status = await authorizationStatus()
            switch status {
            case .denied:
                return .needsSystemSettings

            case .notDetermined:
                await requestPermissionIfNeeded()
                let after = await authorizationStatus()
                guard after == .authorized || after == .provisional || after == .ephemeral else {
                    preferences.setNotificationsEnabled(false)
                    return .needsSystemSettings
                }
                preferences.setNotificationsEnabled(true)
                await refreshTokenIfAuthorized()
                return .enabled

            case .authorized, .provisional, .ephemeral:
                preferences.setNotificationsEnabled(true)
                await refreshTokenIfAuthorized()
                return .enabled

            @unknown default:
                return .needsSystemSettings
            }
        } else {
            preferences.setNotificationsEnabled(false)
            await tokenRegistrar.clearStoredFCMToken()
            return .disabled
        }
    }

    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Permission

    /// Requests notification permission once, after a meaningful user action.
    /// Uses system `authorizationStatus` as source of truth (not only UserDefaults).
    func requestPermissionIfNeeded() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            preferences.markPermissionRequested()
            await refreshTokenIfAuthorized()
            return

        case .denied:
            // iOS will not show the dialog again until the user enables it in Settings.
            preferences.markPermissionRequested()
            #if DEBUG
            print("[Push] notification permission denied — enable in Settings → CircleLink")
            #endif
            return

        case .notDetermined:
            break

        @unknown default:
            break
        }

        do {
            #if DEBUG
            print("[Push] requesting notification permission…")
            #endif
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            preferences.markPermissionRequested()
            #if DEBUG
            print("[Push] permission granted=\(granted)")
            #endif
            guard granted else {
                preferences.setNotificationsEnabled(false)
                return
            }
            preferences.setNotificationsEnabled(true)
            tokenRegistrar.registerForRemoteNotifications()
            await tokenRegistrar.uploadCurrentFCMToken()
        } catch {
            #if DEBUG
            print("[Push] requestAuthorization failed: \(error.localizedDescription)")
            #endif
        }
    }

    /// Call when entering the main app (or attaching the handler) so relaunch
    /// refreshes APNs/FCM without re-prompting.
    func refreshTokenIfAuthorized() async {
        guard preferences.isNotificationsEnabled else { return }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
            || settings.authorizationStatus == .ephemeral else { return }
        tokenRegistrar.registerForRemoteNotifications()
        await tokenRegistrar.uploadCurrentFCMToken()
    }

    func registerForRemoteNotifications() {
        tokenRegistrar.registerForRemoteNotifications()
    }

    // MARK: - APNs / FCM token

    func didRegisterForRemoteNotifications(deviceToken: Data) {
        tokenRegistrar.didRegisterForRemoteNotifications(deviceToken: deviceToken)
    }

    func didFailToRegisterForRemoteNotifications(error: Error) {
        tokenRegistrar.didFailToRegisterForRemoteNotifications(error: error)
    }

    func didReceiveFCMToken(_ token: String?) {
        tokenRegistrar.didReceiveFCMToken(token)
    }

    /// Deletes the local FCM token and clears Firestore. Call while still signed in.
    func clearTokenOnSignOut() async {
        await tokenRegistrar.clearStoredFCMToken()
    }

    // MARK: - Notification handling → deep link

    func handleNotification(userInfo: [AnyHashable: Any]) {
        guard let deepLink = PushDeepLink.parse(userInfo: userInfo) else { return }
        onDeepLink?(deepLink)
    }
}
