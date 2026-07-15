import SwiftUI

@main
struct CircleLinkApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var coordinator: AppCoordinator

    init() {
        // App.init() runs before didFinishLaunching — configure here first.
        FirebaseBootstrap.configureIfNeeded()

        let dependencies = AppDependencies()
        _coordinator = StateObject(wrappedValue: AppCoordinator(dependencies: dependencies))
    }

    var body: some Scene {
        WindowGroup {
            coordinator.rootView
        }
    }
}
