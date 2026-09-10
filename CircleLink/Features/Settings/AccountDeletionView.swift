import SwiftUI

struct AccountDeletionView: View {
    @StateObject private var viewModel: AccountDeletionViewModel
    @State private var showsConfirmation = false

    init(viewModel: AccountDeletionViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CLSpacing.lg) {
                Image(systemName: "person.crop.circle.badge.minus")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(CLColor.error)
                    .accessibilityHidden(true)

                Text("Delete your account")
                    .font(CLTypography.title)
                    .foregroundStyle(CLColor.ink)

                VStack(alignment: .leading, spacing: CLSpacing.sm) {
                    explanation("Your profile is hidden immediately.")
                    explanation("You can restore your account for 30 days. After that, your data is scheduled for cleanup.")
                    explanation("Messages and posts may remain with your identity removed.")
                }

                if viewModel.needsReauthentication {
                    reauthenticationSection
                }

                if let error = viewModel.errorMessage {
                    CLStatusBanner(message: error, style: .error, accessibilityPrefix: "Error")
                }

                Button(role: .destructive) { showsConfirmation = true } label: {
                    Text("Delete Account").frame(maxWidth: .infinity)
                }
                .buttonStyle(CLDestructiveButtonStyle())
                .disabled(viewModel.isDeleting || viewModel.isReauthenticating)
            }
            .padding(.horizontal, CLSpacing.screenHorizontal)
            .padding(.vertical, CLSpacing.lg)
        }
        .clCanvasBackground()
        .navigationTitle("Delete Account")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Delete your account?",
            isPresented: $showsConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Account", role: .destructive) { Task { await viewModel.requestDeletion() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your profile will be hidden now. You have 30 days to restore it.")
        }
    }

    private func explanation(_ text: String) -> some View {
        Label(text, systemImage: "checkmark.circle")
            .font(CLTypography.body)
            .foregroundStyle(CLColor.inkSecondary)
    }

    @ViewBuilder
    private var reauthenticationSection: some View {
        VStack(alignment: .leading, spacing: CLSpacing.sm) {
            CLSectionHeader("Verify your identity")
            switch viewModel.reauthenticationMethod {
            case .apple:
                SystemAppleSignInButton(isEnabled: !viewModel.isReauthenticating) {
                    Task { await viewModel.reauthenticateAndRetry() }
                }
                .frame(height: 52)
                .accessibilityLabel("Continue with Apple")
            case let .email(address):
                Text(address).font(CLTypography.footnote).foregroundStyle(CLColor.inkMuted)
                CLSecureField(title: "Password", prompt: "Password", text: $viewModel.password)
                CLAsyncButton(
                    configuration: .init(title: "Verify and Delete", loadingTitle: "Verifying…", style: .destructive),
                    isDisabled: viewModel.isReauthenticating
                ) {
                    await viewModel.reauthenticateAndRetry()
                }
            case .unavailable:
                Text("Sign out and sign in again, then retry.")
                    .font(CLTypography.body)
                    .foregroundStyle(CLColor.inkSecondary)
            }
        }
        .disabled(viewModel.isDeleting || viewModel.isReauthenticating)
    }
}
