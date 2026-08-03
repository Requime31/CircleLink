import Foundation

/// Shared blocked-user set for Discover / Liked you / Matches.
/// One instance is injected into all Connect screen VMs so filters stay in sync.
@MainActor
final class ConnectBlockFilter {
    enum RefreshResult: Equatable {
        case success
        case failed(String)
        case cancelled
    }

    private(set) var blockedUserIds = Set<String>()
    private(set) var hasSuccessfulSnapshot = false

    private let moderationRepository: ModerationRepository
    private var refreshGeneration = 0

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
        refreshGeneration += 1
        blockedUserIds = []
        hasSuccessfulSnapshot = false
    }

    /// Keeps the last known set on failure and returns a degraded-state message.
    func refresh() async -> RefreshResult {
        refreshGeneration += 1
        let generation = refreshGeneration

        do {
            let fetchedIds = try await moderationRepository.fetchBlockedUserIds()
            guard !Task.isCancelled, generation == refreshGeneration else {
                return .cancelled
            }
            blockedUserIds = fetchedIds
            hasSuccessfulSnapshot = true
            return .success
        } catch is CancellationError {
            return .cancelled
        } catch {
            guard !Task.isCancelled, generation == refreshGeneration else {
                return .cancelled
            }
            // A previous successful set remains safer than replacing it with an empty set.
            return .failed(error.localizedDescription)
        }
    }
}
