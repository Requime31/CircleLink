import Foundation
import UIKit
import UserNotifications

#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif

/// Owns FCM / APNs registration and notification payload parsing.
/// Navigation is forwarded to `AppCoordinator` via `onDeepLink` — never routes itself.
@MainActor
final class PushNotificationHandler: NSObject {
    private static let didRequestPermissionKey = "circlelink.didRequestPushPermission"

    private let userRepository: UserRepository
    private let authRepository: AuthRepository
    private let defaults: UserDefaults

    /// Set by AppCoordinator — only place that may navigate from a push.
    var onDeepLink: ((PushDeepLink) -> Void)?

    private var isRegistering = false

    init(
        userRepository: UserRepository,
        authRepository: AuthRepository,
        defaults: UserDefaults = .standard
    ) {
        self.userRepository = userRepository
        self.authRepository = authRepository
        self.defaults = defaults
        super.init()
    }

    // MARK: - Permission (meaningful moment only)

    /// Requests notification permission once, after a meaningful user action.
    /// Safe to call repeatedly — no-ops after a completed request attempt.
    func requestPermissionIfNeeded() async {
        if defaults.bool(forKey: Self.didRequestPermissionKey) {
            await refreshTokenIfAuthorized()
            return
        }

        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            // Persist only after the system prompt completed (success path).
            defaults.set(true, forKey: Self.didRequestPermissionKey)
            guard granted else { return }
            registerForRemoteNotifications()
            await uploadCurrentFCMToken()
        } catch {
            // Do not set the flag — allow a later meaningful action to retry.
            print("[Push] requestAuthorization failed: \(error.localizedDescription)")
        }
    }

    /// Call when entering the main app (or attaching the handler) so relaunch
    /// refreshes APNs/FCM without re-prompting.
    func refreshTokenIfAuthorized() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional else { return }
        registerForRemoteNotifications()
        await uploadCurrentFCMToken()
    }

    func registerForRemoteNotifications() {
        UIApplication.shared.registerForRemoteNotifications()
    }

    // MARK: - APNs / FCM token

    func didRegisterForRemoteNotifications(deviceToken: Data) {
        #if canImport(FirebaseMessaging)
        Messaging.messaging().apnsToken = deviceToken
        #endif
        Task { await uploadCurrentFCMToken() }
    }

    func didFailToRegisterForRemoteNotifications(error: Error) {
        print("[Push] APNs registration failed: \(error.localizedDescription)")
    }

    func didReceiveFCMToken(_ token: String?) {
        guard let token, !token.isEmpty else { return }
        Task { await storeFCMToken(token) }
    }

    /// Deletes the local FCM token and clears Firestore. Call while still signed in.
    func clearTokenOnSignOut() async {
        #if canImport(FirebaseMessaging)
        do {
            try await Messaging.messaging().deleteToken()
        } catch {
            print("[Push] deleteToken failed: \(error.localizedDescription)")
        }
        #endif

        do {
            try await userRepository.clearFCMToken()
        } catch {
            print("[Push] clearFCMToken failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Notification handling

    func handleNotification(userInfo: [AnyHashable: Any]) {
        guard let deepLink = PushDeepLink.parse(userInfo: userInfo) else { return }
        onDeepLink?(deepLink)
    }

    // MARK: - Private

    private func uploadCurrentFCMToken() async {
        #if canImport(FirebaseMessaging)
        guard !isRegistering else { return }
        isRegistering = true
        defer { isRegistering = false }

        do {
            let token = try await Messaging.messaging().token()
            await storeFCMToken(token)
        } catch {
            print("[Push] FCM token fetch failed: \(error.localizedDescription)")
        }
        #endif
    }

    private func storeFCMToken(_ token: String) async {
        guard authRepository.currentUser != nil else { return }

        do {
            try await userRepository.updateFCMToken(token)
        } catch {
            print("[Push] updateFCMToken failed: \(error.localizedDescription)")
        }
    }
}
