import SwiftUI

enum SettingsDestination: Hashable, CaseIterable {
    case faq, support, blockedPeople, privacy, terms, deleteAccount
}

enum SettingsPresentation {
    static let languageValue = "English"
    static let languageDescription = "More languages coming later"
    static let rateDescription = "Apple decides whether to show the rating prompt."
}

struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel
    private let makeAccountDeletionViewModel: () -> AccountDeletionViewModel
    private let makeBlockedPeopleViewModel: () -> BlockedPeopleViewModel
    private let makeSupportViewModel: () -> SupportViewModel
    @EnvironmentObject private var appearanceStore: AppAppearanceStore
    @Environment(\.scenePhase) private var scenePhase

    init(
        viewModel: SettingsViewModel,
        makeSupportViewModel: @escaping () -> SupportViewModel,
        makeBlockedPeopleViewModel: @escaping () -> BlockedPeopleViewModel,
        makeAccountDeletionViewModel: @escaping () -> AccountDeletionViewModel
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.makeSupportViewModel = makeSupportViewModel
        self.makeBlockedPeopleViewModel = makeBlockedPeopleViewModel
        self.makeAccountDeletionViewModel = makeAccountDeletionViewModel
    }

    var body: some View {
        List {
            preferencesSection
            remindersSection
            languageSection
            helpSection
            legalSection
            accountSection
            aboutSection
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .clCanvasBackground()
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: SettingsDestination.self, destination: destination)
        .task { await viewModel.refresh() }
        .onChange(of: scenePhase) { phase in
            guard phase == .active else { return }
            Task { await viewModel.refresh() }
        }
        .alert("Notifications are off", isPresented: $viewModel.showOpenSettingsAlert) {
            Button("Open Settings") { viewModel.openSystemSettings() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enable notifications for CircleLink in iOS Settings, then turn them on here.")
        }
        .alert("Reminders are off", isPresented: $viewModel.showReminderSettingsAlert) {
            Button("Open Settings") { viewModel.openSystemSettings() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Allow notifications for CircleLink in iOS Settings to use daily Connect reminders.")
        }
        .alert("Reminder unavailable", isPresented: Binding(
            get: { viewModel.reminderError != nil },
            set: { if !$0 { viewModel.reminderError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.reminderError ?? "Please try again.")
        }
        .alert("Rating unavailable", isPresented: $viewModel.showRatingUnavailableAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Try again when CircleLink is active on screen.")
        }
        .clAppear()
    }

    private var preferencesSection: some View {
        Section("Preferences") {
            VStack(alignment: .leading, spacing: CLSpacing.sm) {
                CLSettingsRow(title: "Appearance", systemImage: "circle.lefthalf.filled")
                Picker("Appearance", selection: $appearanceStore.appearance) {
                    ForEach(AppAppearance.allCases, id: \.self) { appearance in
                        Text(appearance.displayName).tag(appearance)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Appearance")
            }
            Toggle(isOn: notificationsBinding) {
                CLSettingsRow(title: "Notifications", subtitle: viewModel.notificationHint, systemImage: "bell")
            }
            .tint(CLColor.primary)
            .disabled(viewModel.isUpdatingNotifications)
            .accessibilityLabel("Notifications")
            .accessibilityValue(viewModel.notificationsEnabled ? "On" : "Off")
        }
        .listRowBackground(CLColor.surface)
    }

    private var remindersSection: some View {
        Section("Reminders") {
            Toggle(isOn: remindersBinding) {
                CLSettingsRow(
                    title: "Enable Reminders",
                    subtitle: viewModel.reminderHint ?? "A daily reminder to check Connect activity.",
                    systemImage: "checkmark.circle"
                )
            }
            .tint(CLColor.primary)
            .disabled(viewModel.isUpdatingReminders)
            .accessibilityValue(viewModel.remindersEnabled ? "On" : "Off")

            if viewModel.remindersEnabled {
                DatePicker(
                    selection: reminderTimeBinding,
                    displayedComponents: .hourAndMinute
                ) {
                    CLSettingsRow(title: "Reminder Time", systemImage: "clock")
                }
                .tint(CLColor.primary)
                .disabled(viewModel.isUpdatingReminders)
            }

            if viewModel.isUpdatingReminders {
                HStack(spacing: CLSpacing.sm) {
                    CLLoadingState(message: "Updating reminder…", isCompact: true)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .listRowBackground(CLColor.surface)
    }

    private var languageSection: some View {
        Section("Language") {
            unavailableRow(systemImage: "globe", title: "App Language",
                           value: SettingsPresentation.languageValue,
                           description: SettingsPresentation.languageDescription)
        }
        .listRowBackground(CLColor.surface)
    }

    private var helpSection: some View {
        Section {
            NavigationLink(value: SettingsDestination.faq) {
                CLSettingsRow(title: "FAQ", systemImage: "questionmark.circle")
            }
            NavigationLink(value: SettingsDestination.support) {
                CLSettingsRow(title: "Contact Support", systemImage: "envelope")
            }
            Button { viewModel.requestAppRating() } label: {
                CLSettingsRow(title: "Rate CircleLink", systemImage: "star")
            }
            .buttonStyle(.plain)
        } header: {
            Text("Help")
        } footer: {
            Text(SettingsPresentation.rateDescription)
                .font(CLTypography.footnote)
        }
        .listRowBackground(CLColor.surface)
    }

    private var legalSection: some View {
        Section("Legal") {
            NavigationLink(value: SettingsDestination.privacy) {
                CLSettingsRow(title: "Privacy Policy", systemImage: "hand.raised")
            }
            NavigationLink(value: SettingsDestination.terms) {
                CLSettingsRow(title: "Terms of Service", systemImage: "doc.text")
            }
        }
        .listRowBackground(CLColor.surface)
    }

    private var accountSection: some View {
        Section {
            NavigationLink(value: SettingsDestination.blockedPeople) {
                CLSettingsRow(title: "Blocked People", systemImage: "person.crop.circle.badge.xmark")
            }
            NavigationLink(value: SettingsDestination.deleteAccount) {
                CLSettingsRow(title: "Delete Account", systemImage: "trash", role: .destructive)
            }
            .accessibilityHint("Opens account deletion information and confirmation")
        } header: {
            Text("Account")
        } footer: {
            Text("Deleting your account deactivates your profile and schedules cleanup after 30 days.")
                .font(CLTypography.footnote)
        }
        .listRowBackground(CLColor.surface)
    }

    private var aboutSection: some View {
        Section("About") {
            CLSettingsRow(title: "CircleLink", systemImage: "info.circle") {
                Text(viewModel.appVersionLabel).font(CLTypography.subheadline).foregroundStyle(CLColor.inkMuted)
            }
        }
        .listRowBackground(CLColor.surface)
    }

    @ViewBuilder private func destination(for route: SettingsDestination) -> some View {
        switch route {
        case .faq: FAQView()
        case .support: SupportView(viewModel: makeSupportViewModel())
        case .blockedPeople: BlockedPeopleView(viewModel: makeBlockedPeopleViewModel())
        case .privacy: LegalDocumentView(document: LegalDocuments.privacyPolicy)
        case .terms: LegalDocumentView(document: LegalDocuments.termsOfService)
        case .deleteAccount: AccountDeletionView(viewModel: makeAccountDeletionViewModel())
        }
    }

    private func unavailableRow(
        systemImage: String, title: String, value: String? = nil, description: String
    ) -> some View {
        CLSettingsRow(title: title, subtitle: description, systemImage: systemImage) {
            if let value {
                Text(value).font(CLTypography.subheadline).foregroundStyle(CLColor.inkMuted)
            }
        }
            .foregroundStyle(CLColor.inkMuted)
            .accessibilityValue([value, description, "Unavailable"].compactMap { $0 }.joined(separator: ", "))
    }

    private var notificationsBinding: Binding<Bool> {
        Binding(get: { viewModel.notificationsEnabled },
                set: { enabled in Task { await viewModel.setNotificationsEnabled(enabled) } })
    }

    private var remindersBinding: Binding<Bool> {
        Binding(get: { viewModel.remindersEnabled },
                set: { enabled in Task { await viewModel.setRemindersEnabled(enabled) } })
    }

    private var reminderTimeBinding: Binding<Date> {
        Binding(
            get: { viewModel.reminderTime.date() },
            set: { date in Task { await viewModel.setReminderTime(.init(date: date)) } }
        )
    }
}
