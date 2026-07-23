import SwiftUI

@main
struct CircleLinkApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var coordinator: AppCoordinator

    init() {
        // App.init() runs before didFinishLaunching — configure here first.
        FirebaseBootstrap.configureIfNeeded()

        let dependencies = AppDependencies()
        let coordinator = AppCoordinator(dependencies: dependencies)
        _coordinator = StateObject(wrappedValue: coordinator)

        // Attach as early as possible; if AppDelegate.shared is not ready yet,
        // `onAppear` below is the fallback.
        AppDelegate.shared?.attach(pushHandler: dependencies.pushNotificationHandler)
    }

    var body: some Scene {
        WindowGroup {
            coordinator.rootView
                .tint(CLColor.primary)
                .onAppear {
                    coordinator.attachPushHandling(to: appDelegate)
                }
        }
    }
}
