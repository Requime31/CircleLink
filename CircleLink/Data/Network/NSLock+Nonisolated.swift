import Foundation

extension NSLock {
    /// Safe to call from any isolation domain — token storage runs off `@MainActor`.
    nonisolated func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }

    /// Void mutation overload — avoids redundant `_ =` at call sites.
    nonisolated func withLock(_ body: () -> Void) {
        lock()
        defer { unlock() }
        body()
    }
}
