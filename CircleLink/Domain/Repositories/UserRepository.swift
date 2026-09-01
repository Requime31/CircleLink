import Foundation

enum AccountLifecycleError: LocalizedError, Equatable {
    case requiresRecentLogin

    var errorDescription: String? {
        "Please verify your identity before continuing."
    }
}

protocol UserRepository: Sendable {
    func fetchProfile(userId: String) async throws -> User
    func updateProfile(_ user: User) async throws
    /// Atomically stores the private birth date and public confirmation/derived age fields.
    func confirmAge(birthDate: Date) async throws
    /// Legacy compatibility until the full-date Age Gate is integrated.
    func confirmAge() async throws
    func requestAccountDeletion(now: Date) async throws
    func restoreAccount() async throws

    /// Stores the device FCM token in the owner's private account document.
    func updateFCMToken(_ token: String) async throws

    /// Clears the stored FCM token (e.g. on sign-out).
    func clearFCMToken() async throws
}
