import FirebaseCore
import UIKit
import UserNotifications

#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif

@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    /// Set in `didFinishLaunching` so `CircleLinkApp` can attach the handler before `onAppear`.
    private(set) static weak var shared: AppDelegate?

    private weak var pushHandler: PushNotificationHandler?
    /// Cold-start / early notification payload held until `attach(pushHandler:)` runs.
    private var pendingLaunchUserInfo: [AnyHashable: Any]?
    private var pendingDeviceToken: Data?
    private var pendingFCMToken: String?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        Self.shared = self

        // Earliest reliable hook — before Auth/Firestore are accessed.
        FirebaseBootstrap.configureIfNeeded()

        UNUserNotificationCenter.current().delegate = self

        #if canImport(FirebaseMessaging)
        Messaging.messaging().delegate = self
        #endif

        if let userInfo = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            pendingLaunchUserInfo = userInfo
        }

        return true
    }

    /// Called from `CircleLinkApp` once DI is ready (prefer before first frame).
    func attach(pushHandler: PushNotificationHandler) {
        self.pushHandler = pushHandler

        if let pendingDeviceToken {
            self.pendingDeviceToken = nil
            pushHandler.didRegisterForRemoteNotifications(deviceToken: pendingDeviceToken)
        }

        if let pendingFCMToken {
            self.pendingFCMToken = nil
            pushHandler.didReceiveFCMToken(pendingFCMToken)
        }

        if let pendingLaunchUserInfo {
            self.pendingLaunchUserInfo = nil
            pushHandler.handleNotification(userInfo: pendingLaunchUserInfo)
        }

        Task { await pushHandler.refreshTokenIfAuthorized() }
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        if let pushHandler {
            pushHandler.didRegisterForRemoteNotifications(deviceToken: deviceToken)
        } else {
            pendingDeviceToken = deviceToken
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        pushHandler?.didFailToRegisterForRemoteNotifications(error: error)
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {
    /// Foreground presentation — show banner so user can tap into deep link.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    /// User tapped a notification — parse payload and forward to AppCoordinator.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        pushHandler?.handleNotification(userInfo: userInfo)
        completionHandler()
    }
}

#if canImport(FirebaseMessaging)
extension AppDelegate: MessagingDelegate {
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        Task { @MainActor in
            if let pushHandler = self.pushHandler {
                pushHandler.didReceiveFCMToken(fcmToken)
            } else {
                self.pendingFCMToken = fcmToken
            }
        }
    }
}
#endif
