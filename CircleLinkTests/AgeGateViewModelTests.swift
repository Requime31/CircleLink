import Foundation
import Testing
@testable import CircleLink

@MainActor
struct AgeGateViewModelTests {
    private let referenceDate = Self.date(2026, 8, 25)

    @Test func exactEighteenthBirthdayCanContinueButFollowingDayCannot() {
        let viewModel = makeViewModel()
        viewModel.selectedBirthDate = Self.date(2008, 8, 25)
        #expect(viewModel.canContinue)
        #expect(viewModel.calculatedAge == 18)

        viewModel.selectedBirthDate = Self.date(2008, 8, 26)
        #expect(!viewModel.canContinue)
        #expect(viewModel.calculatedAge == 17)
    }

    @Test func leapDayBirthdayUsesCompletedCalendarYears() {
        let viewModel = makeViewModel(referenceDate: Self.date(2026, 3, 1))
        viewModel.selectedBirthDate = Self.date(2008, 2, 29)

        #expect(viewModel.calculatedAge == 18)
        #expect(viewModel.canContinue)
    }

    @Test func exactBoundaryUsesLocalDayInUTCPlus14() {
        let zone = TimeZone(secondsFromGMT: 14 * 60 * 60)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let today = calendar.date(from: DateComponents(year: 2026, month: 8, day: 25, hour: 0, minute: 30))!
        let birthday = calendar.date(from: DateComponents(year: 2008, month: 8, day: 25, hour: 12))!
        let viewModel = AgeGateViewModel(
            authRepository: MockAuthRepository(currentUser: MockAuthRepository.sampleUser),
            userRepository: MockUserRepository(),
            onAgeConfirmed: { _ in },
            calendar: calendar,
            timeZone: zone,
            now: { today }
        )

        viewModel.selectedBirthDate = birthday
        #expect(viewModel.canContinue)
        #expect(viewModel.calculatedAge == 18)
    }

    @Test func oldestBoundaryIgnoresClockTime() {
        let viewModel = makeViewModel()
        viewModel.selectedBirthDate = Self.date(1906, 8, 25).addingTimeInterval(-6 * 60 * 60)

        #expect(viewModel.canContinue)
        #expect(viewModel.calculatedAge == 120)
    }

    @Test func invalidFutureDateDoesNotReachRepository() async {
        let users = MockUserRepository()
        let viewModel = makeViewModel(userRepository: users)
        viewModel.selectedBirthDate = Self.date(2030, 1, 1)

        await viewModel.confirmAge()

        #expect(users.confirmAgeBirthDateCallCount == 0)
        if case .error = viewModel.state {} else { Issue.record("Expected validation error") }
    }

    @Test func successPersistsDateFetchesProfileAndCallsBack() async {
        let users = MockUserRepository()
        var confirmedUser: User?
        let viewModel = makeViewModel(userRepository: users) { confirmedUser = $0 }
        viewModel.selectedBirthDate = Self.date(1990, 4, 12)

        await viewModel.confirmAge()

        #expect(users.confirmAgeBirthDateCallCount == 1)
        #expect(users.lastConfirmedBirthDate == Self.date(1990, 4, 12))
        #expect(confirmedUser?.birthDate != nil)
        if case .loaded(true) = viewModel.state {} else { Issue.record("Expected loaded state") }
    }

    @Test func repositoryErrorIsShown() async {
        struct Boom: Error, LocalizedError { var errorDescription: String? { "Age confirm failed" } }
        let users = MockUserRepository()
        users.confirmAgeError = Boom()
        let viewModel = makeViewModel(userRepository: users)

        await viewModel.confirmAge()

        if case let .error(message) = viewModel.state {
            #expect(message == "Age confirm failed")
        } else { Issue.record("Expected repository error") }
    }

    @Test func duplicateTapsOnlyStartOneConfirmation() async {
        let users = MockUserRepository()
        users.shouldSuspendBirthDateConfirmation = true
        let viewModel = makeViewModel(userRepository: users)

        let first = Task { await viewModel.confirmAge() }
        while !users.hasPendingBirthDateConfirmation { await Task.yield() }
        await viewModel.confirmAge()
        #expect(users.confirmAgeBirthDateCallCount == 1)
        users.resumeBirthDateConfirmation()
        await first.value
    }

    @Test func sessionChangeWhileSavingDoesNotCompleteFlow() async {
        let users = MockUserRepository()
        users.shouldSuspendBirthDateConfirmation = true
        let auth = MockAuthRepository(currentUser: MockAuthRepository.sampleUser)
        var callbackCount = 0
        let viewModel = makeViewModel(authRepository: auth, userRepository: users) { _ in callbackCount += 1 }

        let task = Task { await viewModel.confirmAge() }
        while !users.hasPendingBirthDateConfirmation { await Task.yield() }
        auth.currentUser = nil
        users.resumeBirthDateConfirmation()
        await task.value

        #expect(callbackCount == 0)
    }

    @Test func cancellationDoesNotCompleteFlow() async {
        let users = MockUserRepository()
        users.shouldSuspendBirthDateConfirmation = true
        var callbackCount = 0
        let viewModel = makeViewModel(userRepository: users) { _ in callbackCount += 1 }

        let task = Task { await viewModel.confirmAge() }
        while !users.hasPendingBirthDateConfirmation { await Task.yield() }
        task.cancel()
        users.resumeBirthDateConfirmation()
        await task.value

        #expect(callbackCount == 0)
        if case .idle = viewModel.state {} else { Issue.record("Expected idle after cancellation") }
    }

    private func makeViewModel(
        referenceDate: Date? = nil,
        authRepository: MockAuthRepository = MockAuthRepository(currentUser: MockAuthRepository.sampleUser),
        userRepository: MockUserRepository = MockUserRepository(),
        onAgeConfirmed: @escaping (User) -> Void = { _ in }
    ) -> AgeGateViewModel {
        let resolvedReferenceDate = referenceDate ?? self.referenceDate
        return AgeGateViewModel(
            authRepository: authRepository,
            userRepository: userRepository,
            onAgeConfirmed: onAgeConfirmed,
            calendar: Self.calendar,
            timeZone: .gmt,
            now: { resolvedReferenceDate }
        )
    }

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }

    private static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }
}
