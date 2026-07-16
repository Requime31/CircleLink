import Foundation

protocol UserRepository: Sendable {
    func fetchProfile(userId: String) async throws -> User
    func updateProfile(_ user: User) async throws
    func confirmAge() async throws

    /// Stores the device FCM token on `users/{userId}` (device field, not part of `User` profile).
    func updateFCMToken(_ token: String) async throws

    /// Clears the stored FCM token (e.g. on sign-out).
    func clearFCMToken() async throws
}
