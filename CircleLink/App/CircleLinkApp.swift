import SwiftUI

@main
struct CircleLinkApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appearanceStore: AppAppearanceStore
    @StateObject private var coordinator: AppCoordinator

    init() {
        // App.init() runs before didFinishLaunching — configure here first.
        FirebaseBootstrap.configureIfNeeded()

        let dependencies = AppDependencies()
        let coordinator = AppCoordinator(dependencies: dependencies)
        _appearanceStore = StateObject(wrappedValue: dependencies.appearanceStore)
        _coordinator = StateObject(wrappedValue: coordinator)

        // Attach as early as possible; if AppDelegate.shared is not ready yet,
        // `onAppear` below is the fallback.
        AppDelegate.shared?.attach(pushHandler: dependencies.pushNotificationHandler)
    }

    var body: some Scene {
        WindowGroup {
            coordinator.rootView
                .tint(CLColor.primary)
                .preferredColorScheme(appearanceStore.appearance.colorScheme)
                .environmentObject(appearanceStore)
                .onAppear {
                    coordinator.attachPushHandling(to: appDelegate)
                }
        }
    }
}
