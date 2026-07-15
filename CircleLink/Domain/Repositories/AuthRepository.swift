import Foundation

protocol AuthRepository: Sendable {
    func signInWithApple() async throws -> User
    func signInWithEmail(email: String, password: String) async throws -> User
    func signUpWithEmail(email: String, password: String) async throws -> User
    func signOut() throws
    var currentUser: User? { get }
}
