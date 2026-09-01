import Combine
import Foundation

@MainActor
final class AgeGateViewModel: ObservableObject {
    @Published var selectedBirthDate: Date {
        didSet { if case .error = state { state = .idle } }
    }
    @Published private(set) var state: ViewState<Bool> = .idle

    private let authRepository: AuthRepository
    private let userRepository: UserRepository
    let onAgeConfirmed: (User) -> Void
    private let calendar: Calendar
    private let timeZone: TimeZone
    private let now: () -> Date
    private var confirmationGeneration = 0
    private var isConfirming = false

    init(
        authRepository: AuthRepository,
        userRepository: UserRepository,
        onAgeConfirmed: @escaping (User) -> Void,
        calendar: Calendar = Calendar(identifier: .gregorian),
        timeZone: TimeZone = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.authRepository = authRepository
        self.userRepository = userRepository
        self.onAgeConfirmed = onAgeConfirmed
        var configuredCalendar = calendar
        configuredCalendar.timeZone = timeZone
        self.calendar = configuredCalendar
        self.timeZone = timeZone
        self.now = now
        let localCalendar = configuredCalendar
        selectedBirthDate = localCalendar.date(byAdding: .year, value: -25, to: now()) ?? now()
    }

    var minimumBirthDate: Date { dateByAddingYears(-120) ?? now() }
    var maximumBirthDate: Date { dateByAddingYears(-18) ?? now() }

    var calculatedAge: Int {
        AgeCalculator.completedYears(
            since: selectedBirthDate,
            at: now(),
            calendar: calendar,
            timeZone: timeZone
        )
    }

    var canContinue: Bool {
        (18...120).contains(calculatedAge)
            && normalizedDay(selectedBirthDate) >= normalizedDay(minimumBirthDate)
            && normalizedDay(selectedBirthDate) <= normalizedDay(maximumBirthDate)
    }

    func confirmAge() async {
        guard !isConfirming else { return }
        guard canContinue else {
            state = .error("Enter a valid birth date for someone aged 18 or older.")
            return
        }
        guard let userId = authRepository.currentUser?.id else {
            state = .error("Session expired. Please sign in again.")
            return
        }

        isConfirming = true
        confirmationGeneration += 1
        let generation = confirmationGeneration
        defer { if generation == confirmationGeneration { isConfirming = false } }
        state = .loading

        do {
            try Task.checkCancellation()
            try await userRepository.confirmAge(birthDate: selectedBirthDate)
            try Task.checkCancellation()
            guard generation == confirmationGeneration,
                  authRepository.currentUser?.id == userId else { return }
            let profile = try await userRepository.fetchProfile(userId: userId)
            try Task.checkCancellation()
            guard generation == confirmationGeneration,
                  authRepository.currentUser?.id == userId else { return }
            state = .loaded(true)
            onAgeConfirmed(profile)
        } catch is CancellationError {
            guard generation == confirmationGeneration else { return }
            state = .idle
        } catch {
            guard generation == confirmationGeneration,
                  authRepository.currentUser?.id == userId else { return }
            state = .error(error.localizedDescription)
        }
    }

    func resetForm() {
        confirmationGeneration += 1
        isConfirming = false
        var localCalendar = calendar
        localCalendar.timeZone = timeZone
        selectedBirthDate = localCalendar.date(byAdding: .year, value: -25, to: now()) ?? now()
        state = .idle
    }

    private func dateByAddingYears(_ years: Int) -> Date? {
        var localCalendar = calendar
        localCalendar.timeZone = timeZone
        return localCalendar.date(byAdding: .year, value: years, to: localCalendar.startOfDay(for: now()))
    }

    private func normalizedDay(_ date: Date) -> Date { calendar.startOfDay(for: date) }
}
