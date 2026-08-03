import Foundation

/// Shared blocked-user set for Discover / Liked you / Matches.
/// One instance is injected into all Connect screen VMs so filters stay in sync.
@MainActor
final class ConnectBlockFilter {
    private(set) var blockedUserIds = Set<String>()

    private let moderationRepository: ModerationRepository

    init(moderationRepository: ModerationRepository) {
        self.moderationRepository = moderationRepository
    }

    func contains(_ userId: String) -> Bool {
        blockedUserIds.contains(userId)
    }

    func insert(_ userId: String) {
        blockedUserIds.insert(userId)
    }

    func reset() {
        blockedUserIds = []
    }

    /// Keeps the last known set on failure and returns a degraded-state message.
    func refresh() async -> String? {
        do {
            blockedUserIds = try await moderationRepository.fetchBlockedUserIds()
            return nil
        } catch is CancellationError {
            return nil
        } catch {
            // A previous successful set remains safer than replacing it with an empty set.
            return error.localizedDescription
        }
    }
}
