import Foundation
import Supabase

enum SupabaseConfiguration {
    static let chatImagesBucket = "chat-images"
    static let secretsFileName = "SupabaseSecrets"

    private static let secrets: [String: Any]? = {
        guard let path = Bundle.main.path(forResource: secretsFileName, ofType: "plist"),
              let dictionary = NSDictionary(contentsOfFile: path) as? [String: Any] else {
            return nil
        }
        return dictionary
    }()

    static var projectURL: URL? {
        guard let urlString = stringValue(for: "SUPABASE_URL"),
              let url = URL(string: urlString) else {
            return nil
        }
        return url
    }

    static var anonKey: String? {
        stringValue(for: "SUPABASE_ANON_KEY")
    }

    static var isConfigured: Bool {
        projectURL != nil && anonKey != nil
    }

    /// Storage-only client — avoids initializing Supabase Auth (we use Firebase Auth).
    static func makeStorageClient() -> SupabaseStorageClient? {
        guard let projectURL, let anonKey else { return nil }

        let configuration = StorageClientConfiguration(
            url: projectURL.appendingPathComponent("/storage/v1"),
            headers: [
                "Authorization": "Bearer \(anonKey)",
                "Apikey": anonKey
            ],
            logger: nil
        )
        return SupabaseStorageClient(configuration: configuration)
    }

    private static func stringValue(for key: String) -> String? {
        guard let value = secrets?[key] as? String,
              !value.isEmpty,
              !value.hasPrefix("YOUR_") else {
            return nil
        }
        return value
    }
}
