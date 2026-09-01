import Foundation
import Testing
@testable import CircleLink

@MainActor
struct HelpSupportTests {
    @Test
    func faqHasUniqueStructuredCoverage() {
        let items = CircleLinkFAQ.items

        #expect(items.count >= 10)
        #expect(Set(items.map(\.id)).count == items.count)
        #expect(Set(items.map(\.category)) == Set(FAQCategory.allCases))
        #expect(items.allSatisfy { !$0.question.isEmpty && !$0.answer.isEmpty })
    }

    @Test
    func supportPayloadContainsDiagnosticsWithoutPersonalData() {
        let metadata = SupportDeviceMetadata(
            version: "2.1", build: "42", iOSVersion: "18.4", deviceModel: "iPhone17,1"
        )

        let payload = SupportMailPayloadFactory.make(recipient: "help@example.com", metadata: metadata)

        #expect(payload.recipient == "help@example.com")
        #expect(payload.subject.contains("CircleLink Support"))
        #expect(payload.body.contains("App version: 2.1"))
        #expect(payload.body.contains("Build: 42"))
        #expect(payload.body.contains("iOS: 18.4"))
        #expect(payload.body.contains("Device: iPhone17,1"))
        #expect(!payload.body.localizedCaseInsensitiveContains("user id"))
        #expect(!payload.body.localizedCaseInsensitiveContains("chat content"))
        #expect(!payload.body.localizedCaseInsensitiveContains("message content"))
    }

    @Test
    func supportConfigurationIsExplicitlyMarkedAsPlaceholder() {
        #expect(CircleLinkAppConfiguration.supportEmail == "support@circlelink.app")
        #expect(CircleLinkAppConfiguration.supportEmailIsPlaceholder)
    }

    @Test(arguments: [true, false])
    func supportChoosesComposerOrFallback(canSendMail: Bool) {
        let viewModel = SupportViewModel(
            mailPresenter: FakeMailPresenter(canSendMail: canSendMail),
            metadataProvider: FakeMetadataProvider()
        )

        #expect(viewModel.contactAction() == (canSendMail ? .presentComposer : .showFallback))
        #expect(viewModel.payload.mailtoURL?.scheme == "mailto")
    }

    @Test
    func ratingTapInvokesPresenterOnce() {
        let ratingPresenter = FakeRatingPresenter(result: true)
        let viewModel = makeSettingsViewModel(ratingPresenter: ratingPresenter)

        viewModel.requestAppRating()

        #expect(ratingPresenter.callCount == 1)
        #expect(!viewModel.showRatingUnavailableAlert)
    }

    @Test
    func missingForegroundSceneProducesHelpfulState() {
        let ratingPresenter = FakeRatingPresenter(result: false)
        let viewModel = makeSettingsViewModel(ratingPresenter: ratingPresenter)

        viewModel.requestAppRating()

        #expect(ratingPresenter.callCount == 1)
        #expect(viewModel.showRatingUnavailableAlert)
    }

    private func makeSettingsViewModel(ratingPresenter: AppRatingPresenting) -> SettingsViewModel {
        SettingsViewModel(
            pushHandler: PushNotificationHandler(
                userRepository: MockUserRepository(),
                authRepository: MockAuthRepository()
            ),
            reminderScheduler: HelpTestReminderScheduler(),
            reminderPreferencesStore: HelpTestReminderStore(),
            appRatingPresenter: ratingPresenter
        )
    }
}

@MainActor
private struct FakeMailPresenter: SupportMailPresenting {
    let canSendMail: Bool
}

@MainActor
private struct FakeMetadataProvider: SupportDeviceMetadataProviding {
    let metadata = SupportDeviceMetadata(
        version: "1.0", build: "1", iOSVersion: "18.0", deviceModel: "iPhone"
    )
}

@MainActor
private final class FakeRatingPresenter: AppRatingPresenting {
    private(set) var callCount = 0
    let result: Bool

    init(result: Bool) { self.result = result }

    func requestReview() -> Bool {
        callCount += 1
        return result
    }
}

@MainActor
private struct HelpTestReminderScheduler: ReminderScheduling {
    func authorizationStatus() async -> ReminderAuthorizationStatus { .denied }
    func requestAuthorization() async throws -> Bool { false }
    func scheduledTime() async -> ConnectReminderTime? { nil }
    func scheduleDaily(at time: ConnectReminderTime) async throws {}
    func removeReminder() async {}
}

@MainActor
private final class HelpTestReminderStore: ConnectReminderPreferencesStoring {
    private(set) var preferences = ConnectReminderPreferences(isEnabled: false, time: .defaultValue)
    func save(_ preferences: ConnectReminderPreferences) { self.preferences = preferences }
}
