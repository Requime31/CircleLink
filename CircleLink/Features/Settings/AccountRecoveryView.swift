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
                    Text(message).font(CLTypography.footnote).foregroundStyle(CLColor.error)
                }

                if viewModel.canRestore {
                    Button { Task { await viewModel.restore() } } label: {
                        HStack {
                            if viewModel.state == .restoring { ProgressView() }
                            Text("Restore Account")
                        }
                        .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(CLColor.accentSoft)
                    .foregroundStyle(CLColor.ink)
                    .disabled(viewModel.state == .restoring)
                } else if isExpired {
                    Button("Contact Support") {
                        if let url = URL(string: "mailto:support@circlelink.app?subject=Account%20recovery") { openURL(url) }
                    }
                    .buttonStyle(.bordered)
                }

                Button(role: .destructive) {
                    Task { await viewModel.signOut() }
                } label: {
                    HStack {
                        if viewModel.isSigningOut { ProgressView() }
                        Text("Sign Out — keep deletion scheduled")
                    }
                }
                .disabled(viewModel.state == .restoring || viewModel.isSigningOut)
            }
            .padding(.horizontal, CLSpacing.screenHorizontal)
            .padding(.vertical, CLSpacing.xxl)
        }
        .clCanvasBackground()
        .onAppear { viewModel.refreshDeadlineState() }
    }

    private var isExpired: Bool { viewModel.hasExpired }
}
