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
                        .foregroundStyle(CLColor.inkMuted)
                        .frame(maxWidth: .infinity)
                }

                if case let .error(message) = viewModel.saveState {
                    Text(message)
                        .font(CLTypography.footnote)
                        .foregroundStyle(CLColor.error)
                        .multilineTextAlignment(.center)
                        .padding(CLSpacing.sm)
                        .frame(maxWidth: .infinity)
                        .background(CLColor.errorSoft)
                        .clipShape(RoundedRectangle(cornerRadius: CLRadius.sm, style: .continuous))
                        .accessibilityLabel("Error: \(message)")
                }
            }
            .padding(.horizontal, CLSpacing.screenHorizontal)
            .padding(.vertical, CLSpacing.lg)
            .clAppear()
        }
        .clCanvasBackground()
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
        }
        .buttonStyle(CLPrimaryButtonStyle())
        .disabled(!viewModel.canSave || viewModel.saveState == .loading)
        .accessibilityLabel("Save profile changes")
    }
}
