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
                SettingsRowLabel(systemImage: "circle.lefthalf.filled", title: "Appearance")
                Picker("Appearance", selection: $appearanceStore.appearance) {
                    ForEach(AppAppearance.allCases, id: \.self) { appearance in
                        Text(appearance.displayName).tag(appearance)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Appearance")
            }
            Toggle(isOn: notificationsBinding) {
                SettingsRowLabel(systemImage: "bell", title: "Notifications",
                                 description: viewModel.notificationHint)
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
                SettingsRowLabel(
                    systemImage: "checkmark.circle",
                    title: "Enable Reminders",
                    description: viewModel.reminderHint ?? "A daily reminder to check Connect activity."
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
                    SettingsRowLabel(systemImage: "clock", title: "Reminder Time")
                }
                .tint(CLColor.primary)
                .disabled(viewModel.isUpdatingReminders)
            }

            if viewModel.isUpdatingReminders {
                HStack(spacing: CLSpacing.sm) {
                    ProgressView()
                    Text("Updating reminder…")
                        .font(CLTypography.footnote)
                        .foregroundStyle(CLColor.inkMuted)
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
                SettingsRowLabel(systemImage: "questionmark.circle", title: "FAQ")
            }
            NavigationLink(value: SettingsDestination.support) {
                SettingsRowLabel(systemImage: "envelope", title: "Contact Support")
            }
            Button { viewModel.requestAppRating() } label: {
                SettingsRowLabel(systemImage: "star", title: "Rate CircleLink")
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
                SettingsRowLabel(systemImage: "hand.raised", title: "Privacy Policy")
            }
            NavigationLink(value: SettingsDestination.terms) {
                SettingsRowLabel(systemImage: "doc.text", title: "Terms of Service")
            }
        }
        .listRowBackground(CLColor.surface)
    }

    private var accountSection: some View {
        Section {
            NavigationLink(value: SettingsDestination.blockedPeople) {
                SettingsRowLabel(systemImage: "person.crop.circle.badge.xmark", title: "Blocked People")
            }
            NavigationLink(value: SettingsDestination.deleteAccount) {
                SettingsRowLabel(systemImage: "trash", title: "Delete Account", isDestructive: true)
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
            SettingsRowLabel(systemImage: "info.circle", title: "CircleLink", value: viewModel.appVersionLabel)
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
        SettingsRowLabel(systemImage: systemImage, title: title, value: value, description: description)
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

private struct SettingsRowLabel: View {
    let systemImage: String
    let title: String
    var value: String? = nil
    var description: String? = nil
    var isDestructive = false

    var body: some View {
        HStack(alignment: .center, spacing: CLSpacing.md) {
            Image(systemName: systemImage)
                .font(.body)
                .foregroundStyle(isDestructive ? CLColor.error : CLColor.inkSecondary)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: CLSpacing.xxs) {
                Text(title).font(CLTypography.body)
                    .foregroundStyle(isDestructive ? CLColor.error : CLColor.ink)
                if let description {
                    Text(description).font(CLTypography.footnote).foregroundStyle(CLColor.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let value {
                Text(value).font(CLTypography.subheadline).foregroundStyle(CLColor.inkMuted)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(.vertical, CLSpacing.xxs)
        .accessibilityElement(children: .combine)
    }
}
