import Foundation
import Testing
import UserNotifications
@testable import CircleLink

@MainActor
struct ConnectReminderTests {
    @Test
    func enablingWithAuthorizationSchedulesAndPersists() async {
        let context = makeContext(status: .authorized)

        await context.viewModel.setRemindersEnabled(true)

        #expect(context.scheduler.scheduledTimes == [.defaultValue])
        #expect(context.store.preferences == .init(isEnabled: true, time: .defaultValue))
        #expect(context.viewModel.remindersEnabled)
    }

    @Test(arguments: [true, false])
    func enablingWhenUndeterminedUsesPermissionResult(granted: Bool) async {
        let context = makeContext(status: .notDetermined, requestGranted: granted)

        await context.viewModel.setRemindersEnabled(true)

        #expect(context.scheduler.requestAuthorizationCallCount == 1)
        #expect(context.scheduler.scheduledTimes.count == (granted ? 1 : 0))
        #expect(context.viewModel.remindersEnabled == granted)
        #expect(context.store.preferences.isEnabled == granted)
    }

    @Test
    func deniedPermissionKeepsReminderOffAndOffersSettings() async {
        let context = makeContext(status: .denied)

        await context.viewModel.setRemindersEnabled(true)

        #expect(!context.viewModel.remindersEnabled)
        #expect(context.viewModel.showReminderSettingsAlert)
        #expect(context.scheduler.removeCallCount == 1)
        #expect(context.scheduler.scheduledTimes.isEmpty)
    }

    @Test
    func timeChangeReplacesScheduleBeforePersisting() async {
        let context = makeContext(status: .authorized)
        await context.viewModel.setRemindersEnabled(true)
        let newTime = ConnectReminderTime(hour: 8, minute: 45)

        await context.viewModel.setReminderTime(newTime)

        #expect(context.scheduler.scheduledTimes == [.defaultValue, newTime])
        #expect(context.scheduler.pendingTime == newTime)
        #expect(context.store.preferences == .init(isEnabled: true, time: newTime))
    }

    @Test
    func disablingRemovesOnlyTheConnectReminderAndPreservesTime() async {
        let context = makeContext(status: .authorized)
        await context.viewModel.setRemindersEnabled(true)

        await context.viewModel.setRemindersEnabled(false)

        #expect(context.scheduler.removeCallCount == 1)
        #expect(context.store.preferences == .init(isEnabled: false, time: .defaultValue))
    }

    @Test
    func revokedPermissionReconcilesPersistedStateToOff() async {
        let stored = ConnectReminderPreferences(isEnabled: true, time: .init(hour: 20, minute: 15))
        let context = makeContext(status: .denied, preferences: stored)
        context.scheduler.pendingTime = stored.time

        await context.viewModel.reconcileReminders()

        #expect(!context.viewModel.remindersEnabled)
        #expect(!context.store.preferences.isEnabled)
        #expect(context.scheduler.removeCallCount == 1)
        #expect(!context.viewModel.showReminderSettingsAlert)
    }

    @Test
    func reconciliationRepairsMissingOrStaleRequest() async {
        let time = ConnectReminderTime(hour: 18, minute: 30)
        let context = makeContext(
            status: .authorized,
            preferences: .init(isEnabled: true, time: time)
        )
        context.scheduler.pendingTime = .init(hour: 17, minute: 0)

        await context.viewModel.reconcileReminders()

        #expect(context.scheduler.scheduledTimes == [time])
        #expect(context.viewModel.remindersEnabled)
    }

    @Test
    func duplicateEnableAndTimeCallsDoNotScheduleAgain() async {
        let context = makeContext(status: .authorized)
        await context.viewModel.setRemindersEnabled(true)

        await context.viewModel.setRemindersEnabled(true)
        await context.viewModel.setReminderTime(.defaultValue)

        #expect(context.scheduler.scheduledTimes == [.defaultValue])
    }

    @Test
    func userDefaultsStorePersistsTimeWithoutImplicitlyEnabling() {
        let suite = "ConnectReminderTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            Issue.record("Could not create isolated UserDefaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = UserDefaultsConnectReminderPreferencesStore(defaults: defaults)

        #expect(store.preferences == .init(isEnabled: false, time: .defaultValue))

        let saved = ConnectReminderPreferences(isEnabled: true, time: .init(hour: 7, minute: 5))
        store.save(saved)

        #expect(store.preferences == saved)
    }

    @Test
    func foregroundReminderShowsWhilePushNotificationsStaySuppressed() {
        let reminderOptions = AppDelegate.foregroundPresentationOptions(
            notificationIdentifier: UserNotificationReminderScheduler.identifier
        )
        let pushOptions = AppDelegate.foregroundPresentationOptions(
            notificationIdentifier: "remote-message"
        )

        #expect(reminderOptions.contains(.banner))
        #expect(reminderOptions.contains(.sound))
        #expect(pushOptions.isEmpty)
    }

    private func makeContext(
        status: ReminderAuthorizationStatus,
        requestGranted: Bool = true,
        preferences: ConnectReminderPreferences? = nil
    ) -> TestContext {
        let scheduler = FakeReminderScheduler(status: status, requestGranted: requestGranted)
        let store = FakeReminderPreferencesStore(
            preferences: preferences ?? .init(isEnabled: false, time: .defaultValue)
        )
        let pushHandler = PushNotificationHandler(
            userRepository: MockUserRepository(),
            authRepository: MockAuthRepository()
        )
        let viewModel = SettingsViewModel(
            pushHandler: pushHandler,
            reminderScheduler: scheduler,
            reminderPreferencesStore: store,
            appRatingPresenter: StoreKitAppRatingPresenter()
        )
        return TestContext(viewModel: viewModel, scheduler: scheduler, store: store)
    }
}

@MainActor
private struct TestContext {
    let viewModel: SettingsViewModel
    let scheduler: FakeReminderScheduler
    let store: FakeReminderPreferencesStore
}

@MainActor
private final class FakeReminderScheduler: ReminderScheduling {
    var status: ReminderAuthorizationStatus
    var requestGranted: Bool
    var pendingTime: ConnectReminderTime?
    var scheduledTimes: [ConnectReminderTime] = []
    var requestAuthorizationCallCount = 0
    var removeCallCount = 0

    init(status: ReminderAuthorizationStatus, requestGranted: Bool) {
        self.status = status
        self.requestGranted = requestGranted
    }

    func authorizationStatus() async -> ReminderAuthorizationStatus { status }

    func requestAuthorization() async throws -> Bool {
        requestAuthorizationCallCount += 1
        status = requestGranted ? .authorized : .denied
        return requestGranted
    }

    func scheduledTime() async -> ConnectReminderTime? { pendingTime }

    func scheduleDaily(at time: ConnectReminderTime) async throws {
        scheduledTimes.append(time)
        pendingTime = time
    }

    func removeReminder() async {
        removeCallCount += 1
        pendingTime = nil
    }
}

@MainActor
private final class FakeReminderPreferencesStore: ConnectReminderPreferencesStoring {
    private(set) var preferences: ConnectReminderPreferences

    init(preferences: ConnectReminderPreferences) {
        self.preferences = preferences
    }

    func save(_ preferences: ConnectReminderPreferences) {
        self.preferences = preferences
    }
}
