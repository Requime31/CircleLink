import FirebaseCore
import UIKit

@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Earliest reliable hook — before Auth/Firestore are accessed.
        FirebaseBootstrap.configureIfNeeded()
        return true
    }
}
