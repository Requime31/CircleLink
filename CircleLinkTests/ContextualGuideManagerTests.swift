import Foundation
import Testing
@testable import CircleLink

@MainActor
struct ContextualGuideManagerTests {
    @Test func automaticFlowRespectsVersionedCompletion() {
        let repository = GuideUserRepository()
        let manager = ContextualGuideManager(repository: repository)
        manager.configure(user: user(completions: ["community-join": 1]))
        manager.updateAvailableTargets([.communityJoin, .communityPost])
        manager.visit(.communities)
        #expect(manager.activeTip?.target == .communityPost)
    }

    @Test func disappearingTargetSuspendsAndRequeuesTip() {
        let manager = ContextualGuideManager(repository: GuideUserRepository())
        manager.configure(user: user())
        manager.visit(.connect)
        manager.updateAvailableTargets([.connectCard])
        #expect(manager.activeTip?.target == .connectCard)
        manager.updateAvailableTargets([])
        #expect(manager.activeTip == nil)
        manager.updateAvailableTargets([.connectCard])
        #expect(manager.activeTip?.target == .connectCard)
    }

    @Test func manualReplayDoesNotPersist() async {
        let repository = GuideUserRepository()
        let manager = ContextualGuideManager(repository: repository)
        manager.configure(user: user(completions: ["profile-edit": 1, "profile-post": 1]))
        manager.updateAvailableTargets([.profileEdit, .profilePost])
        manager.replay(.profile)
        manager.dismissCurrent()
        manager.dismissCurrent()
        await Task.yield()
        #expect(repository.completions.isEmpty)
    }

    @Test func accountSwitchClearsQueuedState() {
        let manager = ContextualGuideManager(repository: GuideUserRepository())
        manager.configure(user: user(id: "one"))
        manager.updateAvailableTargets([.connectCard])
        manager.visit(.connect)
        #expect(manager.activeTip != nil)
        manager.configure(user: user(id: "two", completions: ["connect-card": 1]))
        #expect(manager.activeTip == nil)
    }

    private func user(id: String = "user", completions: [String: Int] = [:]) -> User {
        User(id: id, displayName: "Guide Tester", ageConfirmedAt: Date(),
             contextualGuideCompletions: completions)
    }
}

private final class GuideUserRepository: UserRepository, @unchecked Sendable {
    var completions: [String: Int] = [:]
    func fetchProfile(userId: String) async throws -> User { User(id: userId, displayName: "Test") }
    func updateProfile(_ user: User) async throws {}
    func confirmAge(birthDate: Date) async throws {}
    func confirmAge() async throws {}
    func requestAccountDeletion(now: Date) async throws {}
    func restoreAccount() async throws {}
    func updateFCMToken(_ token: String) async throws {}
    func clearFCMToken() async throws {}
    func completeContextualGuides(_ values: [String: Int]) async throws {
        completions.merge(values, uniquingKeysWith: max)
    }
}
