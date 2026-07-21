import SwiftUI

struct AuthView: View {
    @ObservedObject var viewModel: AuthViewModel

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("CircleLink")
                    .font(.largeTitle.bold())
                Text("Sign in or create an account")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 32)

            Button {
                Task { await viewModel.signInWithApple() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "apple.logo")
                        .font(.title3)
                    Text("Sign in with Apple")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
                .foregroundStyle(.white)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .accessibilityLabel("Sign in with Apple")

            HStack {
                Rectangle().frame(height: 1).foregroundStyle(.secondary.opacity(0.3))
                Text("or").font(.footnote).foregroundStyle(.secondary)
                Rectangle().frame(height: 1).foregroundStyle(.secondary.opacity(0.3))
            }

            VStack(spacing: 12) {
                TextField("Email", text: $viewModel.email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .accessibilityLabel("Email")

                SecureField("Password", text: $viewModel.password)
                    .textContentType(.password)
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .accessibilityLabel("Password")

                Button {
                    Task { await viewModel.signInWithEmail() }
                } label: {
                    Text("Sign In with Email")
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Sign in with email and password")

                Button {
                    Task { await viewModel.signUpWithEmail() }
                } label: {
                    Text("Create Account")
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Create account with email and password")
            }

            if case .loading = viewModel.state {
                ProgressView("Signing in…")
            }

            if case let .error(message) = viewModel.state {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .accessibilityLabel("Error: \(message)")
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .navigationTitle("Sign In")
        .navigationBarTitleDisplayMode(.inline)
    }
}
