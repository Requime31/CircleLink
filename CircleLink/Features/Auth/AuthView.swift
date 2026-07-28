import SwiftUI

struct AuthView: View {
    @ObservedObject var viewModel: AuthViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: CLSpacing.xl) {
                brandHeader
                    .clAppear()

                signInStack
                    .clAppear(delay: 0.06)
            }
            .padding(.horizontal, CLSpacing.lg)
            .padding(.top, CLSpacing.xxl)
            .padding(.bottom, CLSpacing.xl)
        }
        .scrollDismissesKeyboard(.interactively)
        .clCanvasBackground()
        .navigationTitle("Sign In")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var brandHeader: some View {
        VStack(spacing: CLSpacing.xs) {
            Text("CircleLink")
                .font(CLTypography.largeTitle)
                .foregroundStyle(CLColor.ink)
                .accessibilityAddTraits(.isHeader)

            Text("Sign in or create an account")
                .font(CLTypography.subheadline)
                .foregroundStyle(CLColor.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, CLSpacing.md)
    }

    private var signInStack: some View {
        VStack(spacing: CLSpacing.lg) {
            appleButton
            orDivider
            emailFields
            statusBlock
        }
    }

    /// Apple HIG: Sign in with Apple stays black + white label.
    private var appleButton: some View {
        Button {
            Task { await viewModel.signInWithApple() }
        } label: {
            HStack(spacing: CLSpacing.xs) {
                Image(systemName: "apple.logo")
                    .font(.title3)
                Text("Sign in with Apple")
                    .font(CLTypography.button)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
            .foregroundStyle(.white)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Sign in with Apple")
    }

    private var orDivider: some View {
        HStack(spacing: CLSpacing.sm) {
            Rectangle()
                .fill(CLColor.hairline)
                .frame(height: 1)
            Text("or")
                .font(CLTypography.footnote)
                .foregroundStyle(CLColor.inkMuted)
            Rectangle()
                .fill(CLColor.hairline)
                .frame(height: 1)
        }
        .accessibilityHidden(true)
    }

    private var emailFields: some View {
        VStack(spacing: CLSpacing.sm) {
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
            }
            .buttonStyle(CLPrimaryButtonStyle())
            .accessibilityLabel("Sign in with email and password")

            Button {
                Task { await viewModel.signUpWithEmail() }
            } label: {
                Text("Create Account")
            }
            .buttonStyle(CLSecondaryButtonStyle())
            .accessibilityLabel("Create account with email and password")
        }
    }

    @ViewBuilder
    private var statusBlock: some View {
        if case .loading = viewModel.state {
            ProgressView("Signing in…")
                .tint(CLColor.primary)
                .foregroundStyle(CLColor.inkMuted)
        }

        if case let .error(message) = viewModel.state {
            Text(message)
                .font(CLTypography.footnote)
                .foregroundStyle(CLColor.error)
                .multilineTextAlignment(.center)
                .accessibilityLabel("Error: \(message)")
        }
    }
}
