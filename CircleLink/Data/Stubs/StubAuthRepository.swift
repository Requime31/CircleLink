import Foundation

final class StubAuthRepository: AuthRepository, @unchecked Sendable {
    var reauthenticationMethod: ReauthenticationMethod { .unavailable }
    func reauthenticateWithApple() async throws {}
    func reauthenticateWithEmail(password: String) async throws {}
    private var storedUser: User?

    var currentUser: User? { storedUser }

    init(currentUser: User? = StubAuthRepository.previewUser) {
        storedUser = currentUser
    }

    func signInWithApple() async throws -> User {
        storedUser = Self.previewUser
        return Self.previewUser
    }

    func signInWithEmail(email: String, password: String) async throws -> User {
        storedUser = Self.previewUser
        return Self.previewUser
    }

    func signUpWithEmail(email: String, password: String) async throws -> User {
        storedUser = Self.previewUser
        return Self.previewUser
    }

    func signOut() throws {
        storedUser = nil
    }

    static let previewUser = User(
        id: "stub-user",
        displayName: "CircleLink User",
        avatarURL: nil,
        avatarBase64: nil,
        interests: ["Swift", "iOS"],
        ageConfirmedAt: Date()
    )
}
