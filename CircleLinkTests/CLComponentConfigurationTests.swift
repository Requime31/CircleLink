import SwiftUI
import Testing
@testable import CircleLink

@MainActor
struct CLComponentConfigurationTests {
    @Test(arguments: [
        CLCharacterCounterConfiguration(count: 0, limit: 10, label: "Bio"),
        CLCharacterCounterConfiguration(count: 10, limit: 10, label: "Bio")
    ])
    func characterCounterAcceptsValuesWithinLimit(_ configuration: CLCharacterCounterConfiguration) {
        #expect(configuration.isOverLimit == false)
        #expect(configuration.remaining >= 0)
    }

    @Test func characterCounterExposesOverflowAndAccessibleValue() {
        let configuration = CLCharacterCounterConfiguration(count: 12, limit: 10, label: "Bio")
        #expect(configuration.isOverLimit)
        #expect(configuration.remaining == -2)
        #expect(configuration.accessibilityValue == "Bio, 12 of 10 characters")
    }

    @Test func mediaGridConfigurationIsValueSemantic() {
        let first = CLMediaGridConfiguration(minimumItemWidth: 104, spacing: 4, aspectRatio: 1)
        let second = first
        #expect(first == second)
    }

    @Test func confirmationConfigurationKeepsRoleAndCopyIndependentFromPresentation() {
        let configuration = CLConfirmationConfiguration(
            title: "Delete account?",
            message: "This cannot be undone.",
            confirmTitle: "Delete",
            role: .destructive
        )
        #expect(configuration.role == .destructive)
        #expect(configuration.cancelTitle == "Cancel")
    }
}
