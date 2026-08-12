import SwiftUI

struct AuthView: View {
    @ObservedObject var viewModel: AuthViewModel
    @State private var showEmailForm = false
    @FocusState private var focusedField: AuthField?

    private enum AuthField: Hashable {
        case email
        case password
    }

    var body: some View {
        ZStack {
            CLColor.canvas.ignoresSafeArea()
            ambientBackground

            GeometryReader { geo in
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: CLSpacing.lg)

                        logoMark
                            .padding(.bottom, CLSpacing.xl)
                            .clAppear()

                        headerCopy
                            .padding(.bottom, CLSpacing.xl)
                            .clAppear(delay: 0.04)

                        actionCluster
                            .clAppear(delay: 0.08)

                        termsFooter
                            .padding(.top, CLSpacing.xl)
                            .clAppear(delay: 0.1)

                        Spacer(minLength: CLSpacing.lg)
                    }
                    .padding(.horizontal, CLSpacing.screenHorizontal)
                    .frame(maxWidth: 400)
                    .frame(maxWidth: .infinity)
                    // Spacers only center when the stack is at least as tall as the screen.
                    .frame(minHeight: geo.size.height)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Chrome

    private var ambientBackground: some View {
        ZStack {
            Circle()
                .fill(CLColor.primary.opacity(0.06))
                .frame(width: 280, height: 280)
                .blur(radius: 60)
                .offset(x: -120, y: -180)

            Circle()
                .fill(CLColor.inkMuted.opacity(0.05))
                .frame(width: 220, height: 220)
                .blur(radius: 50)
                .offset(x: 140, y: 280)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var logoMark: some View {
        Image(systemName: "person.3.fill")
            .font(.system(size: 28, weight: .semibold))
            .foregroundStyle(CLColor.primary)
            .frame(width: 64, height: 64)
            .background(CLColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous)
                    .stroke(CLColor.hairline, lineWidth: 1)
            )
            .clFloatingShadow()
            .accessibilityHidden(true)
    }

    private var headerCopy: some View {
        VStack(spacing: CLSpacing.xs) {
            Text("Find your circle.")
                .font(CLTypography.largeTitle)
                .foregroundStyle(CLColor.ink)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            Text("Low-stress social discovery.")
                .font(CLTypography.body)
                .foregroundStyle(CLColor.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var actionCluster: some View {
        VStack(spacing: CLSpacing.md) {
            appleButton

            if showEmailForm {
                emailFields
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                Button {
                    withAnimation(CLMotion.soft) {
                        showEmailForm = true
                    }
                } label: {
                    Text("Continue with Email")
                }
                .buttonStyle(CLSecondaryButtonStyle())
                .accessibilityLabel("Continue with email")

                Button {
                    withAnimation(CLMotion.soft) {
                        showEmailForm = true
                    }
                } label: {
                    (
                        Text("Already have an account? ")
                            .foregroundColor(CLColor.inkSecondary)
                        + Text("Log in")
                            .foregroundColor(CLColor.primary)
                            .fontWeight(.semibold)
                    )
                    .font(CLTypography.footnote)
                }
                .buttonStyle(.plain)
                .padding(.top, CLSpacing.xxs)
                .accessibilityLabel("Log in with email")
            }

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
                    .font(CLTypography.button.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 56)
            .foregroundStyle(.white)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .accessibilityLabel("Sign in with Apple")
    }

    private var emailFields: some View {
        VStack(spacing: CLSpacing.sm) {
            TextField("Email", text: $viewModel.email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(CLColor.ink)
                .focused($focusedField, equals: .email)
                .clTextFieldChrome(isFocused: focusedField == .email)
                .accessibilityLabel("Email")

            SecureField("Password", text: $viewModel.password)
                .textContentType(.password)
                .foregroundStyle(CLColor.ink)
                .focused($focusedField, equals: .password)
                .clTextFieldChrome(isFocused: focusedField == .password)
                .accessibilityLabel("Password")

            Button {
                Task { await viewModel.signInWithEmail() }
            } label: {
                Text("Sign In with Email")
            }
            .buttonStyle(CLEmphasisButtonStyle())
            .disabled(isBusy)
            .accessibilityLabel("Sign in with email and password")

            Button {
                Task { await viewModel.signUpWithEmail() }
            } label: {
                Text("Create Account")
            }
            .buttonStyle(CLSecondaryButtonStyle())
            .disabled(isBusy)
            .accessibilityLabel("Create account with email and password")

            Button {
                withAnimation(CLMotion.soft) {
                    showEmailForm = false
                }
            } label: {
                Text("Back")
                    .font(CLTypography.footnote.weight(.medium))
                    .foregroundStyle(CLColor.inkSecondary)
            }
            .buttonStyle(.plain)
            .padding(.top, CLSpacing.xxs)
            .accessibilityLabel("Back to sign-in options")
        }
    }

    private var termsFooter: some View {
        Text("By continuing, you agree to CircleLink’s Terms of Service and Privacy Policy.")
            .font(CLTypography.caption)
            .foregroundStyle(CLColor.inkMuted)
            .multilineTextAlignment(.center)
            .padding(.horizontal, CLSpacing.md)
            .accessibilityLabel("By continuing, you agree to CircleLink Terms of Service and Privacy Policy")
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

    private var isBusy: Bool {
        if case .loading = viewModel.state { return true }
        return false
    }
}
