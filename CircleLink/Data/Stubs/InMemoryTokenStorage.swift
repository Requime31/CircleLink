import Foundation

final class InMemoryTokenStorage: SecureTokenStorage, @unchecked Sendable {
    private var storage: [TokenStorageKey: String] = [:]

    func save(token: String, for key: TokenStorageKey) throws {
        storage[key] = token
    }

    func load(for key: TokenStorageKey) throws -> String? {
        storage[key]
    }

    func delete(for key: TokenStorageKey) throws {
        storage[key] = nil
    }
}
