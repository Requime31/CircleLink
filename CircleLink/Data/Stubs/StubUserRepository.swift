import Foundation

final class StubUserRepository: UserRepository, @unchecked Sendable {
    func fetchProfile(userId: String) async throws -> User {
        User(
            id: userId,
            displayName: "User \(userId)",
            avatarURL: nil,
            avatarBase64: nil,
            interests: [],
            ageConfirmedAt: nil
        )
    }

    func updateProfile(_ user: User) async throws {}

    func confirmAge() async throws {}

    func updateFCMToken(_ token: String) async throws {}

    func clearFCMToken() async throws {}
}
