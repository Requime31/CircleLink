import Combine
import Foundation

@MainActor
final class ConnectTutorialController: ObservableObject {
    enum Phase: Equatable {
        case inactive
        case demonstratingPass
        case practicingPass
        case demonstratingSayHi
        case practicingSayHi
        case ready
    }

    enum Direction: Equatable {
        case pass
        case sayHi
    }

    @Published private(set) var phase: Phase = .inactive

    var isActive: Bool { phase != .inactive }

    var expectedDirection: Direction? {
        switch phase {
        case .practicingPass: .pass
        case .practicingSayHi: .sayHi
        default: nil
        }
    }

    func start() {
        guard phase == .inactive else { return }
        phase = .demonstratingPass
    }

    func demonstrationFinished(_ direction: Direction) {
        switch (phase, direction) {
        case (.demonstratingPass, .pass):
            phase = .practicingPass
        case (.demonstratingSayHi, .sayHi):
            phase = .practicingSayHi
        default:
            break
        }
    }

    func practiceCompleted(_ direction: Direction) {
        switch (phase, direction) {
        case (.practicingPass, .pass):
            phase = .demonstratingSayHi
        case (.practicingSayHi, .sayHi):
            phase = .ready
        default:
            break
        }
    }

    func complete() {
        phase = .inactive
    }

    func cancel() {
        phase = .inactive
    }
}
