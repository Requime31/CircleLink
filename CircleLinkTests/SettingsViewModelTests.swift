import Foundation
import Testing
import UserNotifications
@testable import CircleLink

@MainActor
struct SettingsViewModelTests {
    @Test func refreshReflectsAuthorizedPreferenceOn() async {
        let settings = MockNotificationSettingsServing()
        settings.authorizationStatusResult = .authorized
        settings.isNotificationsEnabledPreference = true

        let viewModel = SettingsViewModel(notificationSettings: settings)
        await viewModel.refresh()

        #expect(viewModel.notificationsEnabled)
        #expect(viewModel.notificationHint == nil)
        #expect(settings.authorizationStatusCallCount == 1)
    }

    @Test func refreshShowsHintWhenPreferenceOff() async {
        let settings = MockNotificationSettingsServing()
        settings.authorizationStatusResult = .authorized
        settings.isNotificationsEnabledPreference = false

        let viewModel = SettingsViewModel(notificationSettings: settings)
        await viewModel.refresh()

        #expect(!viewModel.notificationsEnabled)
        #expect(viewModel.notificationHint == "Push delivery is paused.")
    }

    @Test func setNotificationsEnabledSurfacesSystemSettingsNeed() async {
        let settings = MockNotificationSettingsServing()
        settings.authorizationStatusResult = .denied
        settings.setNotificationsEnabledResult = .needsSystemSettings

        let viewModel = SettingsViewModel(notificationSettings: settings)
        await viewModel.setNotificationsEnabled(true)

        #expect(settings.setNotificationsEnabledCallCount == 1)
        #expect(settings.lastSetNotificationsEnabledValue == true)
        #expect(viewModel.showOpenSettingsAlert)
        #expect(!viewModel.notificationsEnabled)
    }

    @Test func openSystemSettingsForwardsToService() {
        let settings = MockNotificationSettingsServing()
        let viewModel = SettingsViewModel(notificationSettings: settings)

        viewModel.openSystemSettings()

        #expect(settings.openSystemSettingsCallCount == 1)
    }
}
