import SwiftUI

/// Brand splash sign-in. Soft Orbit canvas + orbit atmosphere; ViewModel bindings unchanged.
///
/// Data flow:
/// User tap → AuthView → AuthViewModel → AuthRepository → Firebase Auth
///   → onAuthenticated → AppCoordinator → Age Gate / Profile / MainTab
struct AuthView: View {
    @ObservedObject var viewModel: AuthViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: CLSpacing.xl) {
                brandHeader
                    .clAppear()

                signInStack
                    .clAppear(delay: 0.08)
            }
            .padding(.horizontal, CLSpacing.lg)
            .padding(.top, CLSpacing.xxl)
            .padding(.bottom, CLSpacing.xl)
        }
        .scrollDismissesKeyboard(.interactively)
        .background {
            SoftOrbitCanvas()
                .ignoresSafeArea()
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Brand

    private var brandHeader: some View {
        VStack(spacing: CLSpacing.sm) {
            // Soft orbit mark — decorative, not a card.
            ZStack {
                Circle()
                    .stroke(CLColor.companionSoft, lineWidth: 2)
                    .frame(width: 72, height: 72)
                Circle()
                    .fill(CLColor.surfaceSoft)
                    .frame(width: 48, height: 48)
                Circle()
                    .fill(CLColor.primary.opacity(0.85))
                    .frame(width: 14, height: 14)
                    .offset(x: 22, y: -10)
            }
            .accessibilityHidden(true)
            .padding(.bottom, CLSpacing.sm)

            Text("CircleLink")
                .font(CLTypography.display)
                .foregroundStyle(CLColor.ink)
                .accessibilityAddTraits(.isHeader)

            Text("Find your circle. Soft connections, real people.")
                .font(CLTypography.callout)
                .foregroundStyle(CLColor.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, CLSpacing.base)
    }

    // MARK: - Actions

    private var signInStack: some View {
        VStack(spacing: CLSpacing.lg) {
            appleButton

            orDivider

            emailFields

            statusBlock
        }
    }

    private var appleButton: some View {
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
            .foregroundStyle(CLColor.onPrimary)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Sign in with Apple")
    }

    private var orDivider: some View {
        HStack(spacing: CLSpacing.md) {
            Rectangle()
                .fill(CLColor.hairline)
                .frame(height: 1)
            Text("or")
                .font(CLTypography.caption)
                .foregroundStyle(CLColor.mutedSoft)
            Rectangle()
                .fill(CLColor.hairline)
                .frame(height: 1)
        }
        .accessibilityHidden(true)
    }

    private var emailFields: some View {
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
                    .foregroundStyle(CLColor.onPrimary)
                    .background(CLColor.primary)
                    .clipShape(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Sign in with email and password")

            Button {
                Task { await viewModel.signUpWithEmail() }
            } label: {
                Text("Create Account")
                    .font(CLTypography.button)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
                    .foregroundStyle(CLColor.primary)
                    .background(CLColor.surfaceCard)
                    .clipShape(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous)
                            .stroke(CLColor.primary, lineWidth: 1.5)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Create account with email and password")
        }
    }

    @ViewBuilder
    private var statusBlock: some View {
        if case .loading = viewModel.state {
            ProgressView("Signing in…")
                .tint(CLColor.primary)
                .foregroundStyle(CLColor.muted)
                .clAppear()
        }

        if case let .error(message) = viewModel.state {
            Text(message)
                .font(CLTypography.caption)
                .foregroundStyle(CLColor.error)
                .multilineTextAlignment(.center)
                .accessibilityLabel("Error: \(message)")
                .clAppear()
        }
    }
}

// MARK: - Atmosphere (view-local)

/// Soft blush canvas with faint orbit rings — brand atmosphere, not interactive chrome.
private struct SoftOrbitCanvas: View {
    var body: some View {
        ZStack {
            CLColor.canvas

            Circle()
                .fill(CLColor.companionSoft.opacity(0.55))
                .frame(width: 280, height: 280)
                .blur(radius: 40)
                .offset(x: -90, y: -180)

            Circle()
                .stroke(CLColor.hairlineSoft.opacity(0.9), lineWidth: 1)
                .frame(width: 220, height: 220)
                .offset(x: 110, y: -120)

            Circle()
                .fill(CLColor.surfaceStrong.opacity(0.45))
                .frame(width: 200, height: 200)
                .blur(radius: 30)
                .offset(x: 80, y: 320)
        }
        .accessibilityHidden(true)
    }
}

#Preview("Auth") {
    NavigationStack {
        AuthView(
            viewModel: AuthViewModel(
                authRepository: StubAuthRepository(),
                onAuthenticated: { _ in }
            )
        )
    }
}
