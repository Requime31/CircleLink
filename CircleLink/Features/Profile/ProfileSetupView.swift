import SwiftUI

/// First-time profile setup in Soft Orbit language. ViewModel bindings unchanged.
///
/// Data flow:
/// Appear → loadProfile → form state
/// Edit fields / toggle interests → ProfileViewModel
/// Continue → saveProfile → host advances when profile complete
struct ProfileSetupView: View {
    @ObservedObject var viewModel: ProfileViewModel
    let onSignOut: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CLSpacing.lg) {
                header
                    .clAppear()

                ProfileFormFields(viewModel: viewModel)
                    .clAppear(delay: 0.05)

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
        .background(CLColor.canvas.ignoresSafeArea())
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
                .font(CLTypography.title)
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
                .foregroundStyle(CLColor.onPrimary)
                .background(viewModel.canSave && viewModel.saveState != .loading
                    ? CLColor.primary
                    : CLColor.primaryDisabled)
                .clipShape(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.canSave || viewModel.saveState == .loading)
        .accessibilityLabel("Continue to main app after completing profile")
    }
}
