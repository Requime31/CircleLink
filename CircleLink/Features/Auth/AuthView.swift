import SwiftUI

struct AuthView: View {
    @ObservedObject var viewModel: AuthViewModel

    var body: some View {
        VStack(spacing: CLSpacing.lg) {
            VStack(spacing: CLSpacing.sm) {
                Text("CircleLink")
                    .font(CLTypography.display)
                    .foregroundStyle(CLColor.ink)
                Text("Sign in or create an account")
                    .font(CLTypography.callout)
                    .foregroundStyle(CLColor.muted)
            }
            .padding(.top, CLSpacing.xl)

            Button {
                Task { await viewModel.signInWithApple() }
            } label: {
                HStack(spacing: CLSpacing.sm) {
                    Image(systemName: "apple.logo")
                        .font(.title3)
                    Text("Sign in with Apple")
                        .font(CLTypography.button)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
                .foregroundStyle(.white)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: CLRadius.sm))
            }
            .accessibilityLabel("Sign in with Apple")

            HStack(spacing: CLSpacing.sm) {
                Rectangle().frame(height: 1).foregroundStyle(CLColor.hairline)
                Text("or")
                    .font(CLTypography.caption)
                    .foregroundStyle(CLColor.muted)
                Rectangle().frame(height: 1).foregroundStyle(CLColor.hairline)
            }

            VStack(spacing: CLSpacing.md) {
                TextField("Email", text: $viewModel.email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(CLColor.ink)
                    .clTextFieldChrome()
                    .accessibilityLabel("Email")

                SecureField("Password", text: $viewModel.password)
                    .textContentType(.password)
                    .foregroundStyle(CLColor.ink)
                    .clTextFieldChrome()
                    .accessibilityLabel("Password")

                Button {
                    Task { await viewModel.signInWithEmail() }
                } label: {
                    Text("Sign In with Email")
                        .font(CLTypography.button)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
                }
                .buttonStyle(.borderedProminent)
                .tint(CLColor.primary)
                .accessibilityLabel("Sign in with email and password")

                Button {
                    Task { await viewModel.signUpWithEmail() }
                } label: {
                    Text("Create Account")
                        .font(CLTypography.button)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
                }
                .buttonStyle(.bordered)
                .tint(CLColor.ink)
                .accessibilityLabel("Create account with email and password")
            }

            if case .loading = viewModel.state {
                ProgressView("Signing in…")
                    .tint(CLColor.primary)
            }

            if case let .error(message) = viewModel.state {
                Text(message)
                    .font(CLTypography.caption)
                    .foregroundStyle(CLColor.error)
                    .multilineTextAlignment(.center)
                    .accessibilityLabel("Error: \(message)")
            }

            Spacer()
        }
        .padding(.horizontal, CLSpacing.lg)
        .background(CLColor.canvas)
        .navigationTitle("Sign In")
        .navigationBarTitleDisplayMode(.inline)
    }
}
