import Foundation

protocol ModerationRepository: Sendable {
    func reportUser(
        userId: String,
        reason: ReportReason,
        chatId: String?,
        communityId: String?
    ) async throws

    func blockUser(_ userId: String) async throws
    func unblockUser(_ userId: String) async throws
    func fetchBlockedUserIds() async throws -> Set<String>
}
