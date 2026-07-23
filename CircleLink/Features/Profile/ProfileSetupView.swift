import SwiftUI

struct ProfileSetupView: View {
    @ObservedObject var viewModel: ProfileViewModel
    let onSignOut: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CLSpacing.lg) {
                header

                ProfileFormFields(viewModel: viewModel)

                saveButton

                if case .loading = viewModel.saveState {
                    ProgressView("Saving profile…")
                        .tint(CLColor.primary)
                        .frame(maxWidth: .infinity)
                }

                if case let .error(message) = viewModel.saveState {
                    Text(message)
                        .font(CLTypography.caption)
                        .foregroundStyle(CLColor.error)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("Error: \(message)")
                }
            }
            .padding(CLSpacing.lg)
        }
        .background(CLColor.canvas)
        .navigationTitle("Profile Setup")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                LogoutButton(action: onSignOut)
            }
        }
        .task {
            await viewModel.loadProfile()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: CLSpacing.sm) {
            Text("Complete Your Profile")
                .font(CLTypography.title2)
                .foregroundStyle(CLColor.ink)

            Text("Add a display name and pick 3–5 interests to join CircleLink.")
                .font(CLTypography.body)
                .foregroundStyle(CLColor.muted)
        }
    }

    private var saveButton: some View {
        Button {
            Task { await viewModel.saveProfile() }
        } label: {
            Text("Continue")
                .font(CLTypography.button)
                .frame(maxWidth: .infinity)
                .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
        }
        .buttonStyle(.borderedProminent)
        .tint(CLColor.primary)
        .disabled(!viewModel.canSave || viewModel.saveState == .loading)
        .accessibilityLabel("Continue to main app after completing profile")
    }
}
