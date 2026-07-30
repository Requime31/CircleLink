import SwiftUI

/// App settings: notifications toggle + About.
/// Hidden chats live on the Chats toolbar. Blocked people is out of scope.
struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel

    @Environment(\.scenePhase) private var scenePhase

    init(pushHandler: PushNotificationHandler) {
        _viewModel = StateObject(wrappedValue: SettingsViewModel(pushHandler: pushHandler))
    }

    var body: some View {
        List {
            Section {
                Toggle(isOn: notificationsBinding) {
                    Label {
                        Text("Notifications")
                            .font(CLTypography.body)
                            .foregroundStyle(CLColor.ink)
                    } icon: {
                        Image(systemName: "bell")
                            .foregroundStyle(CLColor.primaryPressed)
                    }
                }
                .tint(CLColor.primary)
                .disabled(viewModel.isUpdatingNotifications)
                .accessibilityLabel("Notifications")
                .accessibilityValue(viewModel.notificationsEnabled ? "On" : "Off")

                if let hint = viewModel.notificationHint {
                    Text(hint)
                        .font(CLTypography.footnote)
                        .foregroundStyle(CLColor.inkMuted)
                }
            } footer: {
                Text("When off, CircleLink won’t receive push notifications on this device.")
                    .font(CLTypography.footnote)
            }
            .listRowBackground(CLColor.surface)

            Section {
                VStack(alignment: .leading, spacing: CLSpacing.xxs) {
                    Text("CircleLink")
                        .font(CLTypography.headline)
                        .foregroundStyle(CLColor.ink)
                    Text(viewModel.appVersionLabel)
                        .font(CLTypography.footnote)
                        .foregroundStyle(CLColor.inkMuted)
                }
                .padding(.vertical, CLSpacing.xxs)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("CircleLink, \(viewModel.appVersionLabel)")
            } header: {
                Text("About")
            }
            .listRowBackground(CLColor.surface)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .clCanvasBackground()
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.refresh()
        }
        .onChange(of: scenePhase) { phase in
            guard phase == .active else { return }
            Task { await viewModel.refresh() }
        }
        .alert(
            "Notifications are off",
            isPresented: $viewModel.showOpenSettingsAlert
        ) {
            Button("Open Settings") {
                viewModel.openSystemSettings()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enable notifications for CircleLink in iOS Settings, then turn them on here.")
        }
        .clAppear()
    }

    private var notificationsBinding: Binding<Bool> {
        Binding(
            get: { viewModel.notificationsEnabled },
            set: { newValue in
                Task { await viewModel.setNotificationsEnabled(newValue) }
            }
        )
    }
}
