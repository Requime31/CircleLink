import Foundation

extension User {
    /// Profile setup is complete when display name and at least 3 interests are set (Phase 3).
    var isProfileComplete: Bool {
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && interests.count >= 3
    }
}
