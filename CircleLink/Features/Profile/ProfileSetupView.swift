import SwiftUI

struct ProfileSetupView: View {
    @ObservedObject var viewModel: ProfileViewModel
    let onSignOut: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                ProfileFormFields(viewModel: viewModel)

                saveButton

                if case .loading = viewModel.saveState {
                    ProgressView("Saving profile…")
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Complete Your Profile")
                .font(.title2.bold())

            Text("Add a display name and pick 3–5 interests to join CircleLink.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private var saveButton: some View {
        Button {
            Task { await viewModel.saveProfile() }
        } label: {
            Text("Continue")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!viewModel.canSave || viewModel.saveState == .loading)
        .accessibilityLabel("Continue to main app after completing profile")
    }
}
