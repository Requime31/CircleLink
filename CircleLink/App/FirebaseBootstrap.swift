#if canImport(FirebaseCore)
import FirebaseCore
#endif

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

import Foundation

enum FirebaseBootstrap {
    static var isConfigured: Bool {
        #if canImport(FirebaseCore)
        !(FirebaseApp.allApps?.isEmpty ?? true)
        #else
        false
        #endif
    }

    /// Configures Firebase once at app launch.
    /// Requires `GoogleService-Info.plist` in the app bundle (exact filename).
    static func configureIfNeeded() {
        #if canImport(FirebaseCore)
        guard !isConfigured else { return }

        guard let plistPath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") else {
            #if DEBUG
            print(
                """
                [CircleLink] GoogleService-Info.plist not found in app bundle.
                Add the file from Firebase Console to the CircleLink target.
                Filename must be exactly: GoogleService-Info.plist
                See App/FIREBASE_SETUP.md
                """
            )
            #endif
            return
        }

        guard let options = FirebaseOptions(contentsOfFile: plistPath) else {
            #if DEBUG
            print("[CircleLink] Failed to read Firebase options from GoogleService-Info.plist.")
            #endif
            return
        }

        FirebaseApp.configure(options: options)
        configureFirestorePersistence()
        #if DEBUG
        print("[CircleLink] Firebase configured (project: \(options.projectID ?? "unknown")).")
        #endif
        #else
        #if DEBUG
        print(
            """
            [CircleLink] Firebase SDK not linked.
            Add Firebase iOS SDK via SPM — see App/FIREBASE_SETUP.md.
            """
        )
        #endif
        #endif
    }

    #if canImport(FirebaseFirestore)
    private static func configureFirestorePersistence() {
        let db = Firestore.firestore()
        let settings = FirestoreSettings()
        settings.cacheSettings = PersistentCacheSettings()
        db.settings = settings
    }
    #endif
}
