import SwiftUI

/// Edit profile in Soft Orbit language. ViewModel bindings unchanged.
///
/// Data flow:
/// Appear → resetSaveState
/// Edit fields / toggle interests → ProfileViewModel
/// Save → saveProfile → dismiss on success
struct ProfileEditView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CLSpacing.lg) {
                ProfileFormFields(viewModel: viewModel)
                    .clAppear()

                saveButton

                if case .loading = viewModel.saveState {
                    ProgressView("Saving changes…")
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
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.resetSaveState()
        }
    }

    private var saveButton: some View {
        Button {
            Task {
                await viewModel.saveProfile()
                if case .loaded = viewModel.saveState {
                    dismiss()
                }
            }
        } label: {
            Text("Save")
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
        .accessibilityLabel("Save profile changes")
    }
}
