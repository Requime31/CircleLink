import FirebaseFirestore
import Foundation
import Testing
@testable import CircleLink

@MainActor
struct AccountDeactivationTests {
    @Test func legacyMapperDefaultsToActive() {
        let user = FirestoreUserMapper.user(id: "legacy", data: ["displayName": "Legacy"])

        #expect(user.accountState == .active)
        #expect(user.deletionRequestedAt == nil)
        #expect(user.scheduledDeletionAt == nil)
        #expect(user.isSociallyAvailable)
    }

    @Test func mapperReadsDeactivationFields() {
        let requested = Date(timeIntervalSince1970: 1_800_000_000)
        let scheduled = AccountDeletionPolicy.scheduledDeletionDate(from: requested)!
        let user = FirestoreUserMapper.user(
            id: "user-1",
            data: [
                "accountState": "deactivated",
                "deletionRequestedAt": Timestamp(date: requested),
                "scheduledDeletionAt": Timestamp(date: scheduled)
            ]
        )

        #expect(user.accountState == .deactivated)
        #expect(user.deletionRequestedAt == requested)
        #expect(user.scheduledDeletionAt == scheduled)
        #expect(!user.isSociallyAvailable)
    }

    @Test func deadlineIsThirtyCalendarDaysInUTC() throws {
        let start = try #require(AccountDeletionPolicy.calendar.date(from: DateComponents(
            year: 2026, month: 3, day: 8, hour: 1
        )))
        let deadline = try #require(AccountDeletionPolicy.scheduledDeletionDate(from: start))
        let days = AccountDeletionPolicy.calendar.dateComponents([.day], from: start, to: deadline).day

        #expect(days == 30)
    }

    @Test func repeatedRequestPreservesOriginalDeadlineAndRestoreIsIdempotent() async throws {
        let users = MockUserRepository()
        let first = Date(timeIntervalSince1970: 1_800_000_000)
        try await users.requestAccountDeletion(now: first)
        let original = users.profiles["user-1"]?.scheduledDeletionAt

        try await users.requestAccountDeletion(now: first.addingTimeInterval(86_400))
        #expect(users.profiles["user-1"]?.scheduledDeletionAt == original)

        try await users.restoreAccount()
        try await users.restoreAccount()
        #expect(users.profiles["user-1"]?.accountState == .active)
        #expect(users.profiles["user-1"]?.deletionRequestedAt == nil)
        #expect(users.profiles["user-1"]?.scheduledDeletionAt == nil)
    }

    @Test func liveRepositoryRejectsLifecycleOperationsWithoutAuth() async {
        let repository = FirestoreUserRepository(currentUserID: { nil })

        await #expect(throws: FirestoreUserError.self) {
            try await repository.requestAccountDeletion(now: Date())
        }
        await #expect(throws: FirestoreUserError.self) {
            try await repository.restoreAccount()
        }
    }

    @Test func sessionChangeDuringRequestDoesNotDeactivateAnotherSession() async {
        let users = MockUserRepository()
        users.shouldSuspendLifecycle = true
        let task = Task { try await users.requestAccountDeletion(now: Date()) }
        while !users.hasPendingLifecycleOperation { await Task.yield() }
        users.lifecycleCurrentUserID = "other-user"
        users.resumeLifecycleOperation()

        await #expect(throws: FirestoreUserError.self) { try await task.value }
        #expect(users.profiles["user-1"]?.accountState == .active)
    }
}
