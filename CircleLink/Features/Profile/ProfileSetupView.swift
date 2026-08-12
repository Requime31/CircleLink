import SwiftUI

struct ProfileSetupView: View {
    @ObservedObject var viewModel: ProfileViewModel
    let onSignOut: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: CLSpacing.lg) {
                    header
                    ProfileFormFields(viewModel: viewModel)

                    if case .loading = viewModel.saveState {
                        ProgressView("Saving profile…")
                            .tint(CLColor.primary)
                            .foregroundStyle(CLColor.inkMuted)
                            .frame(maxWidth: .infinity)
                    }

                    if case let .error(message) = viewModel.saveState {
                        Text(message)
                            .font(CLTypography.footnote)
                            .foregroundStyle(CLColor.error)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .accessibilityLabel("Error: \(message)")
                    }
                }
                .padding(.horizontal, CLSpacing.screenHorizontal)
                .padding(.top, CLSpacing.lg)
                .padding(.bottom, CLSpacing.md)
                .clAppear()
            }

            saveButton
                .padding(.horizontal, CLSpacing.screenHorizontal)
                .padding(.top, CLSpacing.sm)
                .padding(.bottom, CLSpacing.md)
                .background(CLColor.canvas.ignoresSafeArea(edges: .bottom))
        }
        .clCanvasBackground()
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
        VStack(alignment: .leading, spacing: CLSpacing.xs) {
            Text("Complete Your Profile")
                .font(CLTypography.title)
                .foregroundStyle(CLColor.ink)
                .accessibilityAddTraits(.isHeader)

            Text("Add a display name and pick 3–5 interests to join CircleLink.")
                .font(CLTypography.body)
                .foregroundStyle(CLColor.inkSecondary)
        }
    }

    private var saveButton: some View {
        Button {
            Task { await viewModel.saveProfile() }
        } label: {
            Text("Continue")
        }
        .buttonStyle(CLPrimaryButtonStyle())
        .disabled(!viewModel.canSave || viewModel.saveState == .loading)
        .accessibilityLabel("Continue to main app after completing profile")
    }
}
