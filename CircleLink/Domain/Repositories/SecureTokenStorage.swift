import Foundation

enum TokenStorageKey: String, Sendable {
    case firebaseIDToken
}

protocol SecureTokenStorage: Sendable {
    func save(token: String, for key: TokenStorageKey) throws
    func load(for key: TokenStorageKey) throws -> String?
    func delete(for key: TokenStorageKey) throws
}
