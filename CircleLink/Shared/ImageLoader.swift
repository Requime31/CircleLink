import Foundation
import UIKit

/// Async image loading with in-memory cache for remote avatar URLs.
actor ImageLoader {
    static let shared = ImageLoader()

    private let cache = NSCache<NSURL, UIImage>()
    private var inFlight: [URL: Task<UIImage?, Error>] = [:]

    func load(from url: URL) async throws -> UIImage? {
        if let cached = cache.object(forKey: url as NSURL) {
            return cached
        }

        if let existing = inFlight[url] {
            return try await existing.value
        }

        let task = Task<UIImage?, Error> {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
                return nil
            }
            return UIImage(data: data)
        }

        inFlight[url] = task
        defer { inFlight[url] = nil }

        let image = try await task.value
        if let image {
            cache.setObject(image, forKey: url as NSURL)
        }
        return image
    }

    func clearCache() {
        cache.removeAllObjects()
    }
}
