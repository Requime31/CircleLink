import FirebaseAuth
import Foundation

/// Provides Firebase ID tokens for WebSocket authentication.
protocol IDTokenProviding: Sendable {
    /// Returns a Firebase ID token, or `nil` when no user is signed in.
    func fetchIDToken(forceRefresh: Bool) async throws -> String?
}

/// Production implementation backed by Firebase Auth.
final class FirebaseIDTokenProvider: IDTokenProviding, @unchecked Sendable {
    func fetchIDToken(forceRefresh: Bool) async throws -> String? {
        guard FirebaseBootstrap.isConfigured else { return nil }
        guard let user = Auth.auth().currentUser else { return nil }
        return try await user.getIDToken(forcingRefresh: forceRefresh)
    }
}
