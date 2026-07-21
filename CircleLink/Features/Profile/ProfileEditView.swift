import SwiftUI

struct ProfileEditView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ProfileFormFields(viewModel: viewModel)

                saveButton

                if case .loading = viewModel.saveState {
                    ProgressView("Saving changes…")
                        .frame(maxWidth: .infinity)
                }

                if case let .error(message) = viewModel.saveState {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("Error: \(message)")
                }
            }
            .padding(24)
        }
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
                .frame(maxWidth: .infinity)
                .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!viewModel.canSave || viewModel.saveState == .loading)
        .accessibilityLabel("Save profile changes")
    }
}
