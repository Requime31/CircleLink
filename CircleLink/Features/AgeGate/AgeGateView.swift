import SwiftUI

struct AgeGateView: View {
    @ObservedObject var viewModel: AgeGateViewModel
    let onSignOut: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: CLSpacing.lg) {
                Image(systemName: "18.circle")
                    .font(.system(size: 48, weight: .regular))
                    .foregroundStyle(CLColor.inkMuted)
                    .padding(CLSpacing.md)
                    .background(Circle().fill(CLColor.primarySoft))
                    .accessibilityHidden(true)

                VStack(spacing: CLSpacing.xs) {
                    Text("Age Verification")
                        .font(CLTypography.title)
                        .foregroundStyle(CLColor.ink)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)

                    Text("CircleLink is for users 18 and older. Please confirm your age to continue.")
                        .font(CLTypography.body)
                        .foregroundStyle(CLColor.inkSecondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: CLSpacing.md) {
                    Toggle(isOn: $viewModel.isAgeConfirmed) {
                        Text("I am 18 or older")
                            .font(CLTypography.body)
                            .foregroundStyle(CLColor.ink)
                    }
                    .tint(CLColor.primary)
                    .clCardStyle()
                    .clSoftSpring(value: viewModel.isAgeConfirmed)
                    .accessibilityLabel("I am 18 or older")

                    Button {
                        Task { await viewModel.confirmAge() }
                    } label: {
                        Text("Continue")
                    }
                    .buttonStyle(CLPrimaryButtonStyle())
                    .disabled(!viewModel.canContinue)
                    .accessibilityLabel("Continue after confirming age")
                    .clSoftSpring(value: viewModel.canContinue)

                    statusBlock
                }
                .clAppear(delay: 0.05)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, CLSpacing.lg)
            .padding(.top, CLSpacing.xxl)
            .padding(.bottom, CLSpacing.xl)
            .clAppear()
        }
        .scrollDismissesKeyboard(.interactively)
        .clCanvasBackground()
        .navigationTitle("Age Gate")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                LogoutButton(action: onSignOut)
            }
        }
    }

    @ViewBuilder
    private var statusBlock: some View {
        if case .loading = viewModel.state {
            ProgressView("Saving…")
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
