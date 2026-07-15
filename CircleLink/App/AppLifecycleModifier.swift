import SwiftUI

/// Bridges SwiftUI ScenePhase to WebSocketConnectionManager without UI imports in the manager.
struct AppLifecycleModifier: ViewModifier {
    let connectionManager: WebSocketConnectionManager
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .onAppear {
                connectionManager.handleLifecycleChange(mapPhase(scenePhase))
            }
            .onChange(of: scenePhase) { newPhase in
                connectionManager.handleLifecycleChange(mapPhase(newPhase))
            }
    }

    private func mapPhase(_ phase: ScenePhase) -> AppLifecycleState {
        switch phase {
        case .active:
            return .foreground
        case .background, .inactive:
            return .background
        @unknown default:
            return .background
        }
    }
}

extension View {
    func trackAppLifecycle(connectionManager: WebSocketConnectionManager) -> some View {
        modifier(AppLifecycleModifier(connectionManager: connectionManager))
    }
}
