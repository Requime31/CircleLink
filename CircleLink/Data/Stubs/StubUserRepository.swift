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

    func fetchProfiles(userIds: [String]) async throws -> [String: User] {
        var result: [String: User] = [:]
        for id in Set(userIds) where !id.isEmpty {
            result[id] = try await fetchProfile(userId: id)
        }
        return result
    }

    func updateProfile(_ user: User) async throws {}

    func confirmAge() async throws {}

    func updateFCMToken(_ token: String) async throws {}

    func clearFCMToken() async throws {}
}
