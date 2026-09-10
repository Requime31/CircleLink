import SwiftUI

struct AccountRecoveryView: View {
    @ObservedObject var viewModel: AccountRecoveryViewModel
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(spacing: CLSpacing.lg) {
                Image(systemName: isExpired ? "clock.badge.exclamationmark" : "arrow.counterclockwise.circle")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(isExpired ? CLColor.error : CLColor.primary)
                    .accessibilityHidden(true)

                Text(isExpired ? "Restoration period ended" : "Your account is deactivated")
                    .font(CLTypography.title)
                    .foregroundStyle(CLColor.ink)
                    .multilineTextAlignment(.center)

                if let deadline = viewModel.deadline {
                    Text(isExpired ? "Deletion was scheduled after \(deadline.formatted(date: .long, time: .shortened))." : "You can restore your account until \(deadline.formatted(date: .long, time: .shortened)).")
                        .font(CLTypography.body)
                        .foregroundStyle(CLColor.inkSecondary)
                        .multilineTextAlignment(.center)
                }

                if case let .error(message) = viewModel.state {
                    CLStatusBanner(message: message, style: .error, accessibilityPrefix: "Error")
                }

                if viewModel.canRestore {
                    CLAsyncButton(
                        configuration: .init(title: "Restore Account", loadingTitle: "Restoring…", style: .emphasis),
                        isDisabled: viewModel.state == .restoring
                    ) {
                        await viewModel.restore()
                    }
                } else if isExpired {
                    Button("Contact Support") {
                        if let url = URL(string: "mailto:support@circlelink.app?subject=Account%20recovery") { openURL(url) }
                    }
                    .buttonStyle(.bordered)
                }

                CLAsyncButton(
                    configuration: .init(
                        title: "Sign Out — keep deletion scheduled",
                        loadingTitle: "Signing out…",
                        style: .destructive
                    ),
                    isDisabled: viewModel.state == .restoring || viewModel.isSigningOut
                ) {
                    await viewModel.signOut()
                }
            }
            .padding(.horizontal, CLSpacing.screenHorizontal)
            .padding(.vertical, CLSpacing.xxl)
        }
        .clCanvasBackground()
        .onAppear { viewModel.refreshDeadlineState() }
    }

    private var isExpired: Bool { viewModel.hasExpired }
}
