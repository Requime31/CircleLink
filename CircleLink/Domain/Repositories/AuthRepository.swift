import Foundation

enum ReauthenticationMethod: Equatable, Sendable {
    case apple
    case email(address: String)
    case unavailable
}

protocol AuthRepository: Sendable {
    func signInWithApple() async throws -> User
    func signInWithEmail(email: String, password: String) async throws -> User
    func signUpWithEmail(email: String, password: String) async throws -> User
    var reauthenticationMethod: ReauthenticationMethod { get }
    func reauthenticateWithApple() async throws
    func reauthenticateWithEmail(password: String) async throws
    func signOut() throws
    var currentUser: User? { get }
}
