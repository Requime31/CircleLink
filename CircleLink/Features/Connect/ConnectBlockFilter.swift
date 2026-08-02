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

    /// Fail closed: keep the last known set if refresh fails.
    func refresh() async {
        do {
            blockedUserIds = try await moderationRepository.fetchBlockedUserIds()
        } catch {
            // Keep last known block set so a refresh blip cannot re-surface blocked people.
        }
    }
}
