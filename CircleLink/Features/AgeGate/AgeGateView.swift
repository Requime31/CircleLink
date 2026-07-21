import SwiftUI

struct AgeGateView: View {
    @ObservedObject var viewModel: AgeGateViewModel
    let onSignOut: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "18.circle")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text("Age Verification")
                .font(.title.bold())

            Text("CircleLink is for users 18 and older. Please confirm your age to continue.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Toggle(isOn: $viewModel.isAgeConfirmed) {
                Text("I am 18 or older")
            }
            .toggleStyle(.switch)
            .accessibilityLabel("I am 18 or older")

            Button {
                Task { await viewModel.confirmAge() }
            } label: {
                Text("Continue")
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canContinue)
            .accessibilityLabel("Continue after confirming age")

            if case .loading = viewModel.state {
                ProgressView("Saving…")
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
        .padding(24)
        .navigationTitle("Age Gate")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                LogoutButton(action: onSignOut)
            }
        }
    }
}
