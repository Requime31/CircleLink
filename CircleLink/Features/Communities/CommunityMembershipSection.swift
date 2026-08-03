import SwiftUI

/// Join / leave / open group chat actions for community detail.
struct CommunityMembershipSection: View {
    @ObservedObject var viewModel: CommunityDetailViewModel
    let onOpenGroupChat: (String, String) -> Void

    var body: some View {
        VStack(spacing: CLSpacing.sm) {
            if viewModel.isMember {
                Button {
                    Task { await viewModel.leave() }
                } label: {
                    membershipButtonLabel(
                        title: "Leave Community",
                        isLoading: viewModel.isMembershipActionInFlight
                    )
                }
                .buttonStyle(CLSecondaryButtonStyle())
                .disabled(viewModel.isMembershipActionInFlight)
                .accessibilityLabel("Leave community")

                Button {
                    Task {
                        if let result = await viewModel.openGroupChat() {
                            onOpenGroupChat(result.chatId, result.title)
                        }
                    }
                } label: {
                    membershipButtonLabel(
                        title: "Open Group Chat",
                        isLoading: viewModel.isOpeningGroupChat
                    )
                }
                .buttonStyle(CLPrimaryButtonStyle())
                .disabled(viewModel.isOpeningGroupChat || viewModel.isMembershipActionInFlight)
                .accessibilityLabel("Open group chat")
                .accessibilityHint("Opens the community group chat")
            } else {
                Button {
                    Task { await viewModel.join() }
                } label: {
                    membershipButtonLabel(
                        title: "Join Community",
                        isLoading: viewModel.isMembershipActionInFlight
                    )
                }
                .buttonStyle(CLPrimaryButtonStyle())
                .disabled(viewModel.isMembershipActionInFlight)
                .accessibilityLabel("Join community")
            }

            if let membershipErrorMessage = viewModel.membershipErrorMessage {
                Text(membershipErrorMessage)
                    .font(CLTypography.footnote)
                    .foregroundStyle(CLColor.error)
                    .padding(CLSpacing.sm)
                    .frame(maxWidth: .infinity)
                    .background(CLColor.errorSoft)
                    .clipShape(RoundedRectangle(cornerRadius: CLRadius.sm, style: .continuous))
                    .multilineTextAlignment(.center)
                    .accessibilityLabel("Membership error: \(membershipErrorMessage)")
            }
        }
    }

    @ViewBuilder
    private func membershipButtonLabel(title: String, isLoading: Bool) -> some View {
        if isLoading {
            ProgressView()
                .tint(CLColor.onPrimary)
        } else {
            Text(title)
        }
    }
}
