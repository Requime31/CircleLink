#if canImport(FirebaseCore)
import FirebaseCore
#endif

import Foundation

enum FirebaseBootstrap {
    static var isConfigured: Bool {
        #if canImport(FirebaseCore)
        FirebaseApp.app() != nil
        #else
        false
        #endif
    }

    /// Configures Firebase once at app launch.
    /// Requires `GoogleService-Info.plist` in the app bundle (exact filename).
    static func configureIfNeeded() {
        #if canImport(FirebaseCore)
        guard FirebaseApp.app() == nil else { return }

        guard let plistPath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") else {
            print(
                """
                [CircleLink] GoogleService-Info.plist not found in app bundle.
                Add the file from Firebase Console to the CircleLink target.
                Filename must be exactly: GoogleService-Info.plist
                See App/FIREBASE_SETUP.md
                """
            )
            return
        }

        guard let options = FirebaseOptions(contentsOfFile: plistPath) else {
            print("[CircleLink] Failed to read Firebase options from GoogleService-Info.plist.")
            return
        }

        FirebaseApp.configure(options: options)
        print("[CircleLink] Firebase configured (project: \(options.projectID ?? "unknown")).")
        #else
        print(
            """
            [CircleLink] Firebase SDK not linked.
            Add Firebase iOS SDK via SPM — see App/FIREBASE_SETUP.md.
            """
        )
        #endif
    }
}
