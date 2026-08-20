import Combine
import Foundation

/// Data flow:
/// User enters birth year → taps Continue
///   → AgeGateView
///   → AgeGateViewModel.confirmAge()
///   → local age check (18+)
///   → UserRepository.confirmAge()
///   → Firestore `ageConfirmedAt`
///   → fetchProfile → onAgeConfirmed(User)
///   → AppCoordinator → Profile Setup / MainTab
///
/// Birth year is validated on-device only for now (not stored).
@MainActor
final class AgeGateViewModel: ObservableObject {
    @Published var birthYearText = ""
    @Published private(set) var state: ViewState<Bool> = .idle

    private let authRepository: AuthRepository
    private let userRepository: UserRepository
    let onAgeConfirmed: (User) -> Void

    private let calendar: Calendar
    private let minimumAge = 18
    private var confirmationGeneration = 0
    private var isConfirming = false

    init(
        authRepository: AuthRepository,
        userRepository: UserRepository,
        onAgeConfirmed: @escaping (User) -> Void,
        calendar: Calendar = .current
    ) {
        self.authRepository = authRepository
        self.userRepository = userRepository
        self.onAgeConfirmed = onAgeConfirmed
        self.calendar = calendar
    }

    /// Parsed YYYY when the field looks complete.
    var birthYear: Int? {
        let digits = birthYearText.filter(\.isNumber)
        guard digits.count == 4, let year = Int(digits) else { return nil }
        return year
    }

    var canContinue: Bool {
        isAtLeastMinimumAge
    }

    var isAtLeastMinimumAge: Bool {
        guard let birthYear else { return false }
        let currentYear = calendar.component(.year, from: Date())
        // Reject absurd future / ancient years.
        guard birthYear >= 1900, birthYear <= currentYear else { return false }
        return currentYear - birthYear >= minimumAge
    }

    func updateBirthYearText(_ raw: String) {
        let digits = String(raw.filter(\.isNumber).prefix(4))
        birthYearText = digits
        // Clear stale validation errors while the user edits.
        if case .error = state {
            state = .idle
        }
    }

    func confirmAge() async {
        guard !isConfirming else { return }
        guard let birthYear else {
            state = .error("Enter your year of birth (YYYY).")
            return
        }

        let currentYear = calendar.component(.year, from: Date())
        guard birthYear >= 1900, birthYear <= currentYear else {
            state = .error("Enter a valid year of birth.")
            return
        }

        guard currentYear - birthYear >= minimumAge else {
            state = .error("You must be 18 or older to use CircleLink.")
            return
        }

        isConfirming = true
        confirmationGeneration += 1
        let generation = confirmationGeneration
        defer {
            if generation == confirmationGeneration {
                isConfirming = false
            }
        }
        state = .loading
        do {
            try await userRepository.confirmAge()
            guard generation == confirmationGeneration else { return }
            guard let userId = authRepository.currentUser?.id else {
                state = .error("Session expired. Please sign in again.")
                return
            }
            let profile = try await userRepository.fetchProfile(userId: userId)
            guard generation == confirmationGeneration,
                  authRepository.currentUser?.id == userId,
                  !Task.isCancelled else { return }
            state = .loaded(true)
            onAgeConfirmed(profile)
        } catch {
            guard generation == confirmationGeneration else { return }
            state = .error(error.localizedDescription)
        }
    }

    func resetForm() {
        confirmationGeneration += 1
        isConfirming = false
        birthYearText = ""
        state = .idle
    }
}
