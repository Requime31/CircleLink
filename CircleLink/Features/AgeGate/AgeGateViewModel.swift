import Combine
import Foundation

@MainActor
final class AgeGateViewModel: ObservableObject {
    @Published var isAgeConfirmed = false
    @Published private(set) var state: ViewState<Bool> = .idle

    private let confirmAge: ConfirmAgeUseCase
    let onAgeConfirmed: (User) -> Void

    init(
        confirmAge: ConfirmAgeUseCase,
        onAgeConfirmed: @escaping (User) -> Void
    ) {
        self.confirmAge = confirmAge
        self.onAgeConfirmed = onAgeConfirmed
    }

    var canContinue: Bool {
        isAgeConfirmed
    }

    func confirmAge() async {
        guard isAgeConfirmed else { return }

        state = .loading
        do {
            let profile = try await confirmAge.execute()
            state = .loaded(true)
            onAgeConfirmed(profile)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func resetForm() {
        isAgeConfirmed = false
        state = .idle
    }
}
