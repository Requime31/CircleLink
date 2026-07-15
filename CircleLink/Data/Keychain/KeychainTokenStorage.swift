import Security
import Foundation

enum KeychainError: LocalizedError {
    case encodingFailed
    case saveFailed(OSStatus)
    case loadFailed(OSStatus)
    case deleteFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode token for Keychain storage."
        case let .saveFailed(status):
            return "Failed to save token to Keychain (OSStatus \(status))."
        case let .loadFailed(status):
            return "Failed to load token from Keychain (OSStatus \(status))."
        case let .deleteFailed(status):
            return "Failed to delete token from Keychain (OSStatus \(status))."
        }
    }
}

final class KeychainTokenStorage: SecureTokenStorage, @unchecked Sendable {
    private let service = "com.roman.helloswift.CircleLink.tokens"

    func save(token: String, for key: TokenStorageKey) throws {
        guard let data = token.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        let query = baseQuery(for: key)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }
        if updateStatus != errSecItemNotFound {
            throw KeychainError.saveFailed(updateStatus)
        }

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainError.saveFailed(addStatus)
        }
    }

    func load(for key: TokenStorageKey) throws -> String? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw KeychainError.loadFailed(status)
        }
        guard let data = item as? Data, let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        return token
    }

    func delete(for key: TokenStorageKey) throws {
        let status = SecItemDelete(baseQuery(for: key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    private func baseQuery(for key: TokenStorageKey) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]
    }
}
