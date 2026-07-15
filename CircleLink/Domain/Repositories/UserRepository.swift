import Foundation

protocol UserRepository: Sendable {
    func fetchProfile(userId: String) async throws -> User
    func updateProfile(_ user: User) async throws
    func confirmAge() async throws
}
