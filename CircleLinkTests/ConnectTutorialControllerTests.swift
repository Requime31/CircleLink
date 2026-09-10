import Testing
@testable import CircleLink

@MainActor
struct ConnectTutorialControllerTests {
    @Test func followsHybridTutorialSequence() {
        let controller = ConnectTutorialController()

        controller.start()
        #expect(controller.phase == .demonstratingPass)
        #expect(controller.expectedDirection == nil)

        controller.demonstrationFinished(.pass)
        #expect(controller.phase == .practicingPass)
        #expect(controller.expectedDirection == .pass)

        controller.practiceCompleted(.sayHi)
        #expect(controller.phase == .practicingPass)

        controller.practiceCompleted(.pass)
        #expect(controller.phase == .demonstratingSayHi)

        controller.demonstrationFinished(.sayHi)
        #expect(controller.phase == .practicingSayHi)
        #expect(controller.expectedDirection == .sayHi)

        controller.practiceCompleted(.sayHi)
        #expect(controller.phase == .ready)

        controller.complete()
        #expect(controller.phase == .inactive)
    }

    @Test func cancellationReturnsToInactiveState() {
        let controller = ConnectTutorialController()
        controller.start()
        controller.demonstrationFinished(.pass)

        controller.cancel()

        #expect(controller.phase == .inactive)
        #expect(controller.isActive == false)
    }
}
