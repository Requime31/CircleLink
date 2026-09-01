import Foundation
import Testing
@testable import CircleLink

@MainActor
struct SettingsPresentationTests {
    @Test func routeMapContainsOnlyImplementedDestinations() {
        #expect(SettingsDestination.allCases == [
            .faq, .support, .blockedPeople, .privacy, .terms, .deleteAccount
        ])
    }

    @Test func unavailableRowsExplainTheirStatus() {
        #expect(SettingsPresentation.languageValue == "English")
        #expect(SettingsPresentation.languageDescription.contains("coming later"))
        #expect(SettingsPresentation.rateDescription.contains("Apple decides"))
    }
}
