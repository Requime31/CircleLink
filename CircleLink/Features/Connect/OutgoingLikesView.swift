import SwiftUI

/// Pending connection requests sent by the current user.
/// This screen is intentionally informational: profile and moderation only.
struct OutgoingLikesView: View {
    @ObservedObject var viewModel: ConnectViewModel
    let onSelectPeer: (OutgoingConnectRequestItem) -> Void
    let onReport: (String, String) -> Void
    let onBlock: (String, String) -> Void

    var body: some View {
        Group {
            switch viewModel.outgoingPendingState {
            case .idle, .loading:
                CLLoadingState(message: "Loading people…")
            case .empty:
                CLEmptyState(
                    systemImage: "paperplane",
                    title: "No one is waiting",
                    message: "People you say hi to will appear here while you wait for a response."
                )
            case let .error(message):
                CLEmptyState(
                    systemImage: "exclamationmark.triangle",
                    title: "Couldn’t load people",
                    message: message,
                    actionTitle: "Retry",
                    actionAccessibilityLabel: "Retry loading people you liked"
                ) {
                    Task { await viewModel.loadOutgoingPending() }
                }
            case let .loaded(items):
                outgoingList(items)
                    .clAppear()
            }
        }
        .clCanvasBackground()
        .navigationTitle("People You Liked")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.refreshOutgoingPending()
        }
    }

    private func outgoingList(_ items: [OutgoingConnectRequestItem]) -> some View {
        ScrollView {
            LazyVStack(spacing: CLSpacing.sm) {
                ForEach(items) { item in
                    OutgoingLikeRow(
                        item: item,
                        sharedInterests: viewModel.sharedInterests(with: item.peer),
                        isCancelling: viewModel.respondingRequestId == item.request.id,
                        onOpen: { onSelectPeer(item) },
                        onUndo: { Task { await viewModel.cancelOutgoingLike(requestId: item.request.id) } }
                    )
                    .contextMenu {
                        Button("Undo Like", systemImage: "arrow.uturn.backward") {
                            Task { await viewModel.cancelOutgoingLike(requestId: item.request.id) }
                        }
                        Button("Report…") {
                            onReport(item.peer.id, item.peer.displayName)
                        }
                        Button("Block…", role: .destructive) {
                            viewModel.prepareBlockConfirmation()
                            onBlock(item.peer.id, item.peer.displayName)
                        }
                    }
                }
            }
            .padding(.horizontal, CLSpacing.screenHorizontal)
            .padding(.vertical, CLSpacing.md)
        }
        .refreshable {
            await viewModel.loadOutgoingPending(showLoading: false)
        }
    }

}

private struct OutgoingLikeRow: View {
    let item: OutgoingConnectRequestItem
    let sharedInterests: [String]
    let isCancelling: Bool
    let onOpen: () -> Void
    let onUndo: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: CLSpacing.sm) {
            Button(action: onOpen) {
                rowContent
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(item.peer.displayNameWithAge), waiting for response")
            .accessibilityHint("Opens profile")

            Button(action: onUndo) {
                if isCancelling {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "arrow.uturn.backward")
                }
            }
            .buttonStyle(.bordered)
            .tint(CLColor.inkSecondary)
            .disabled(isCancelling)
            .accessibilityLabel("Undo like for \(item.peer.displayName)")
        }
        .padding(CLSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CLColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: CLRadius.xl, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: CLRadius.xl, style: .continuous)
                .stroke(CLColor.hairline, lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: CLRadius.xl, style: .continuous))
    }

    private var rowContent: some View {
        HStack(alignment: .center, spacing: CLSpacing.md) {
            AvatarImageView(
                localPreview: nil,
                avatarBase64: item.peer.avatarBase64,
                avatarURL: item.peer.avatarURL,
                size: 64
            )

            VStack(alignment: .leading, spacing: CLSpacing.xxs) {
                Text(item.peer.displayNameWithAge)
                    .font(CLTypography.headline)
                    .foregroundStyle(CLColor.ink)
                    .fixedSize(horizontal: false, vertical: true)

                if !sharedInterests.isEmpty {
                    Text("Shared: \(sharedInterests.prefix(3).joined(separator: ", "))")
                        .font(CLTypography.subheadline)
                        .foregroundStyle(CLColor.inkSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Label("Waiting for response", systemImage: "clock")
                    .font(CLTypography.footnote)
                    .foregroundStyle(CLColor.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
