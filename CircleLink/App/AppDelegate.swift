import FirebaseCore
import UIKit

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
