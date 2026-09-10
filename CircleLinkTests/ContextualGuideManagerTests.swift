import Foundation
import Testing
@testable import CircleLink

@MainActor
struct ContextualGuideManagerTests {
    private let defaults = UserDefaults(suiteName: "GuideTests.\(UUID().uuidString)")!

    @Test func automaticFlowRespectsVersionedCompletion() {
        let repository = GuideUserRepository()
        let manager = ContextualGuideManager(repository: repository, defaults: defaults)
        manager.configure(user: user(completions: ["community-join": 1]))
        manager.visit(.communities)
        manager.updateAvailableTargets([.communityJoin, .communityPost])
        #expect(manager.activeTip?.target == .communityPost)
    }

    @Test func disappearingTargetSuspendsAndRequeuesTip() {
        let manager = ContextualGuideManager(repository: GuideUserRepository(), defaults: defaults)
        manager.configure(user: user())
        manager.visit(.connect)
        manager.updateAvailableTargets([.connectCard])
        #expect(manager.activeTip?.target == .connectCard)
        manager.updateAvailableTargets([])
        #expect(manager.activeTip == nil)
        manager.updateAvailableTargets([.connectCard])
        #expect(manager.activeTip?.target == .connectCard)
    }

    @Test func suspendedGuideCompletesOnlyAfterFeatureFlowFinishes() async {
        let repository = GuideUserRepository()
        let manager = ContextualGuideManager(repository: repository, defaults: defaults)
        manager.configure(user: user())
        manager.visit(.connect)
        manager.updateAvailableTargets([.connectCard])

        manager.suspendCurrent()
        #expect(manager.activeTip == nil)
        #expect(repository.completions.isEmpty)

        // Layout and blocker updates happen whenever the tutorial changes phase.
        // They must not reactivate the feature-owned introductory guide.
        manager.updateBlocked(true)
        manager.updateBlocked(false)
        manager.updateAvailableTargets([.connectCard])
        #expect(manager.activeTip == nil)

        manager.updateBlocked(true)
        manager.updateBlocked(false)
        manager.updateAvailableTargets([.connectCard])
        #expect(manager.activeTip == nil)

        manager.completeGuide(id: "connect-card", version: 2)
        await manager.retryPendingCompletions()?.value
        #expect(repository.completions == ["connect-card": 2])
    }

    @Test func abandonedFeatureFlowCanOfferItsGuideAgain() {
        let manager = ContextualGuideManager(repository: GuideUserRepository(), defaults: defaults)
        manager.configure(user: user())
        manager.visit(.connect)
        manager.updateAvailableTargets([.connectCard])

        manager.suspendCurrent()
        manager.releaseSuspendedGuide(id: "connect-card")
        manager.visit(.connect)
        manager.updateAvailableTargets([.connectCard])

        #expect(manager.activeTip?.target == .connectCard)
    }

    @Test func manualReplayDoesNotPersist() async {
        let repository = GuideUserRepository()
        let manager = ContextualGuideManager(repository: repository, defaults: defaults)
        manager.configure(user: user(completions: ["profile-edit": 1, "profile-post": 1]))
        manager.replay(.profile)
        manager.updateAvailableTargets([.profileEdit, .profilePost])
        #expect(manager.activeTip?.target == .profilePost)
        manager.dismissCurrent()
        manager.dismissCurrent()
        await Task.yield()
        #expect(repository.completions.isEmpty)
    }

    @Test func accountSwitchClearsQueuedState() {
        let manager = ContextualGuideManager(repository: GuideUserRepository(), defaults: defaults)
        manager.configure(user: user(id: "one"))
        manager.visit(.connect)
        manager.updateAvailableTargets([.connectCard])
        #expect(manager.activeTip != nil)
        manager.configure(user: user(id: "two", completions: ["connect-card": 2]))
        #expect(manager.activeTip == nil)
    }

    @Test func switchingTabsRejectsPreviousScreensAndStaleLayoutReports() {
        let manager = ContextualGuideManager(repository: GuideUserRepository(), defaults: defaults)
        manager.configure(user: user())
        manager.visit(.chats)
        let oldGeneration = manager.presentationGeneration
        manager.updateAvailableTargets([.chatUnread])
        #expect(manager.activeTip?.target == .chatUnread)

        manager.visit(.connect)
        #expect(manager.activeTip == nil)
        manager.updateAvailableTargets([.chatUnread, .connectCard], generation: oldGeneration)
        #expect(manager.activeTip == nil)
        manager.updateAvailableTargets([.chatUnread])
        #expect(manager.activeTip == nil)
        manager.updateAvailableTargets([.chatUnread, .connectCard])
        #expect(manager.activeTip?.target == .connectCard)
    }

    @Test func unblockingRequiresFreshGeometry() {
        let manager = ContextualGuideManager(repository: GuideUserRepository(), defaults: defaults)
        manager.configure(user: user())
        manager.visit(.connect)
        manager.updateAvailableTargets([.connectCard])
        manager.updateBlocked(true)
        #expect(manager.activeTip == nil)
        manager.updateAvailableTargets([.connectCard])
        manager.updateBlocked(false)
        #expect(manager.activeTip == nil)
        manager.updateAvailableTargets([.connectCard])
        #expect(manager.activeTip?.target == .connectCard)
    }

    @Test func accountSwitchClearsBlockersAndTargets() {
        let manager = ContextualGuideManager(repository: GuideUserRepository(), defaults: defaults)
        manager.configure(user: user(id: "one"))
        manager.visit(.connect)
        manager.updateAvailableTargets([.connectCard])
        manager.updateBlocked(true)
        manager.configure(user: user(id: "two"))
        manager.visit(.connect)
        #expect(manager.isBlocked == false)
        #expect(manager.activeTip == nil)
        manager.updateAvailableTargets([.connectCard])
        #expect(manager.activeTip?.target == .connectCard)
    }

    @Test func failedProgressSurvivesRelaunchAndRetriesForSameAccount() async {
        let repository = GuideUserRepository()
        repository.shouldFail = true
        let manager = ContextualGuideManager(repository: repository, defaults: defaults)
        manager.configure(user: user(id: "offline-user"))
        manager.visit(.connect)
        manager.updateAvailableTargets([.connectCard])
        manager.dismissCurrent()
        await manager.retryPendingCompletions()?.value
        #expect(manager.lastPersistenceError != nil)

        let nextRepository = GuideUserRepository()
        let restored = ContextualGuideManager(repository: nextRepository, defaults: defaults)
        restored.configure(user: user(id: "offline-user"))
        restored.visit(.connect)
        restored.updateAvailableTargets([.connectCard])
        #expect(restored.activeTip == nil)
        await restored.retryPendingCompletions()?.value
        #expect(nextRepository.completions == ["connect-card": 2])
        #expect(restored.lastPersistenceError == nil)
        #expect(defaults.dictionary(forKey: "CircleLink.GuidePending.offline-user")?.isEmpty == true)
    }

    @Test func pendingProgressDoesNotTransferToAnotherAccount() async {
        let repository = GuideUserRepository()
        let manager = ContextualGuideManager(repository: repository, defaults: defaults)
        manager.configure(user: user(id: "one"))
        manager.visit(.connect)
        manager.updateAvailableTargets([.connectCard])
        manager.dismissCurrent()
        let oldWrite = manager.retryPendingCompletions()
        // Switch before the queued write enters the repository.
        manager.configure(user: user(id: "two"))
        await oldWrite?.value
        #expect(repository.completions.isEmpty)
        manager.visit(.connect)
        manager.updateAvailableTargets([.connectCard])
        #expect(manager.activeTip?.target == .connectCard)
        #expect(defaults.dictionary(forKey: "CircleLink.GuidePending.one")?["connect-card"] as? Int == 2)
    }

    private func user(id: String = "user", completions: [String: Int] = [:]) -> User {
        User(id: id, displayName: "Guide Tester", ageConfirmedAt: Date(),
             contextualGuideCompletions: completions)
    }
}

private final class GuideUserRepository: UserRepository, @unchecked Sendable {
    var completions: [String: Int] = [:]
    var shouldFail = false
    func fetchProfile(userId: String) async throws -> User { User(id: userId, displayName: "Test") }
    func updateProfile(_ user: User) async throws {}
    func confirmAge(birthDate: Date) async throws {}
    func confirmAge() async throws {}
    func requestAccountDeletion(now: Date) async throws {}
    func restoreAccount() async throws {}
    func updateFCMToken(_ token: String) async throws {}
    func clearFCMToken() async throws {}
    func completeContextualGuides(_ values: [String: Int]) async throws {
        if shouldFail { throw URLError(.notConnectedToInternet) }
        completions.merge(values, uniquingKeysWith: max)
    }
}
