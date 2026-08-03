import Foundation

protocol AuthRepository: Sendable {
    func signInWithApple() async throws -> User
    func signInWithEmail(email: String, password: String) async throws -> User
    func signUpWithEmail(email: String, password: String) async throws -> User
    func signOut() async throws
    /// Restores an existing auth session and returns the loaded profile, or `nil` if none.
    func restoreSessionProfile() async throws -> User?
    var currentUser: User? { get }
}
