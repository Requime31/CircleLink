import Foundation

/// WebSocket server URL resolved from the app bundle.
/// Read from `@MainActor` composition root (`AppDependencies`) and injected into clients.
enum WebSocketConfiguration {
    /// Reads `WEBSOCKET_URL` from Info.plist. Falls back to localhost for development.
    static var serverURL: URL {
        if let urlString = Bundle.main.object(forInfoDictionaryKey: "WEBSOCKET_URL") as? String,
           let url = URL(string: urlString) {
            return url
        }

        #if DEBUG
        return URL(string: "ws://localhost:8080")!
        #else
        return URL(string: "wss://circlelink-ws.up.railway.app")!
        #endif
    }
}
