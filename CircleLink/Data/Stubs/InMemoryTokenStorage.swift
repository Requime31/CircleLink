import Foundation

final class InMemoryTokenStorage: SecureTokenStorage, @unchecked Sendable {
    private let lock = NSLock()
    private nonisolated(unsafe) var storage: [TokenStorageKey: String] = [:]

    nonisolated func save(token: String, for key: TokenStorageKey) throws {
        lock.withLock {
            storage[key] = token
        }
    }

    nonisolated func load(for key: TokenStorageKey) throws -> String? {
        lock.withLock {
            storage[key]
        }
    }

    nonisolated func delete(for key: TokenStorageKey) throws {
        lock.withLock {
            storage[key] = nil
        }
    }
}
