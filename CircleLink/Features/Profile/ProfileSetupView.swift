import SwiftUI

struct ProfileSetupView: View {
    @ObservedObject var viewModel: ProfileViewModel
    let onSignOut: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: CLSpacing.lg) {
                    header
                    ProfileFormFields(viewModel: viewModel, mode: .setup)

                    if case let .error(message) = viewModel.saveState {
                        CLStatusBanner(message: message, style: .error, accessibilityPrefix: "Error")
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

            CLOnboardingStepIndicator(currentStep: 2)
                .frame(maxWidth: .infinity)
        }
    }

    private var saveButton: some View {
        CLAsyncButton(
            configuration: .init(
                title: "Continue",
                loadingTitle: "Saving profile…",
                accessibilityLabel: "Continue to main app after completing profile"
            ),
            isDisabled: !viewModel.canSave || viewModel.saveState == .loading
        ) {
            await viewModel.saveProfile()
        }
    }
}
