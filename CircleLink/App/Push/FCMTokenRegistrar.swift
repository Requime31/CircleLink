import Foundation
import UIKit

#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif

/// Owns APNs → FCM token lifecycle and Firestore persistence.
/// Does not navigate; does not own notification permission UI.
@MainActor
final class FCMTokenRegistrar {
    private let userRepository: UserRepository
    private let authRepository: AuthRepository
    private let preferences: PushNotificationPreferenceStore

    private var isRegistering = false

    init(
        userRepository: UserRepository,
        authRepository: AuthRepository,
        preferences: PushNotificationPreferenceStore
    ) {
        self.userRepository = userRepository
        self.authRepository = authRepository
        self.preferences = preferences
    }

    func registerForRemoteNotifications() {
        UIApplication.shared.registerForRemoteNotifications()
    }

    func didRegisterForRemoteNotifications(deviceToken: Data) {
        #if canImport(FirebaseMessaging)
        Messaging.messaging().apnsToken = deviceToken
        #endif
        Task { await uploadCurrentFCMToken() }
    }

    func didFailToRegisterForRemoteNotifications(error: Error) {
        #if DEBUG
        print("[Push] APNs registration failed: \(error.localizedDescription)")
        #endif
    }

    func didReceiveFCMToken(_ token: String?) {
        guard let token, !token.isEmpty else { return }
        Task { await storeFCMToken(token) }
    }

    /// Deletes the local FCM token and clears Firestore. Call while still signed in.
    func clearStoredFCMToken() async {
        #if canImport(FirebaseMessaging)
        do {
            try await Messaging.messaging().deleteToken()
        } catch {
            #if DEBUG
            print("[Push] deleteToken failed: \(error.localizedDescription)")
            #endif
        }
        #endif

        do {
            try await userRepository.clearFCMToken()
        } catch {
            #if DEBUG
            print("[Push] clearFCMToken failed: \(error.localizedDescription)")
            #endif
        }
    }

    func uploadCurrentFCMToken() async {
        guard preferences.isNotificationsEnabled else { return }
        #if canImport(FirebaseMessaging)
        guard !isRegistering else { return }
        isRegistering = true
        defer { isRegistering = false }

        do {
            let token = try await Messaging.messaging().token()
            await storeFCMToken(token)
        } catch {
            #if DEBUG
            print("[Push] FCM token fetch failed: \(error.localizedDescription)")
            #endif
        }
        #endif
    }

    private func storeFCMToken(_ token: String) async {
        guard preferences.isNotificationsEnabled else { return }
        guard authRepository.currentUser != nil else { return }

        do {
            try await userRepository.updateFCMToken(token)
        } catch {
            #if DEBUG
            print("[Push] updateFCMToken failed: \(error.localizedDescription)")
            #endif
        }
    }
}
