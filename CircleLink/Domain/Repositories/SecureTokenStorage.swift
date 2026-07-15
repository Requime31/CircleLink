import Foundation

enum TokenStorageKey: String, Sendable {
    case firebaseIDToken
}

protocol SecureTokenStorage: Sendable {
    nonisolated func save(token: String, for key: TokenStorageKey) throws
    nonisolated func load(for key: TokenStorageKey) throws -> String?
    nonisolated func delete(for key: TokenStorageKey) throws
}
