import SwiftUI

struct ProfileEditView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CLSpacing.lg) {
                ProfileFormFields(viewModel: viewModel)

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
        .background(CLColor.canvas)
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
        }
        .buttonStyle(.borderedProminent)
        .tint(CLColor.primary)
        .disabled(!viewModel.canSave || viewModel.saveState == .loading)
        .accessibilityLabel("Save profile changes")
    }
}
