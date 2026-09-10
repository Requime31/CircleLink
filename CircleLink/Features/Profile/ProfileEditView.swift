import SwiftUI

struct ProfileEditView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showsBirthDateConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CLSpacing.lg) {
                ProfileFormFields(viewModel: viewModel, mode: .edit)

                saveButton

                if case let .error(message) = viewModel.saveState {
                    CLStatusBanner(message: message, style: .error, accessibilityPrefix: "Error")
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
        .onDisappear {
            viewModel.discardUnsavedAvatarChanges()
        }
        .alert("Confirm Date of Birth", isPresented: $showsBirthDateConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Save") { save(confirmBirthDateChange: true) }
        } message: {
            Text(viewModel.birthDateChangeMessage)
        }
    }

    private var saveButton: some View {
        Button {
            if viewModel.hasBirthDateChange {
                showsBirthDateConfirmation = true
            } else {
                save(confirmBirthDateChange: false)
            }
        } label: {
            Text("Save")
        }
        .buttonStyle(CLPrimaryButtonStyle())
        .disabled(!viewModel.canSave || viewModel.saveState == .loading)
        .accessibilityLabel("Save profile changes")
    }

    private func save(confirmBirthDateChange: Bool) {
        Task {
            await viewModel.saveProfile(confirmBirthDateChange: confirmBirthDateChange)
            if case .loaded = viewModel.saveState { dismiss() }
        }
    }
}
