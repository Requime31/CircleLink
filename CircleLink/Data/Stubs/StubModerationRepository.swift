import Foundation

final class StubModerationRepository: ModerationRepository, @unchecked Sendable {
    private var blockedIds: Set<String>
    var fetchBlockedUserIdsError: Error?

    init(blockedUserIds: Set<String> = []) {
        self.blockedIds = blockedUserIds
    }

    func reportUser(
        userId: String,
        reason: ReportReason,
        chatId: String?,
        communityId: String?
    ) async throws {}

    func blockUser(_ userId: String) async throws {
        blockedIds.insert(userId)
    }

    func unblockUser(_ userId: String) async throws {
        blockedIds.remove(userId)
    }

    func fetchBlockedUserIds() async throws -> Set<String> {
        if let fetchBlockedUserIdsError {
            throw fetchBlockedUserIdsError
        }
        blockedIds
    }
}
