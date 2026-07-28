import SwiftUI

struct AgeGateView: View {
    @ObservedObject var viewModel: AgeGateViewModel
    let onSignOut: () -> Void

    var body: some View {
        VStack(spacing: CLSpacing.lg) {
            Image(systemName: "18.circle")
                .font(.system(size: 56))
                .foregroundStyle(CLColor.muted)
                .accessibilityHidden(true)

            Text("Age Verification")
                .font(CLTypography.title)
                .foregroundStyle(CLColor.ink)

            Text("CircleLink is for users 18 and older. Please confirm your age to continue.")
                .font(CLTypography.body)
                .foregroundStyle(CLColor.muted)
                .multilineTextAlignment(.center)

            Toggle(isOn: $viewModel.isAgeConfirmed) {
                Text("I am 18 or older")
                    .foregroundStyle(CLColor.ink)
            }
            .toggleStyle(.switch)
            .tint(CLColor.primary)
            .accessibilityLabel("I am 18 or older")

            Button {
                Task { await viewModel.confirmAge() }
            } label: {
                Text("Continue")
                    .font(CLTypography.button)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
            }
            .buttonStyle(.borderedProminent)
            .tint(CLColor.primary)
            .disabled(!viewModel.canContinue)
            .accessibilityLabel("Continue after confirming age")

            if case .loading = viewModel.state {
                ProgressView("Saving…")
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
        .padding(CLSpacing.lg)
        .background(CLColor.canvas)
        .navigationTitle("Age Gate")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                LogoutButton(action: onSignOut)
            }
        }
    }
}
