import SwiftUI

/// Incoming Connect requests — pushed from Discover.
struct LikedYouView: View {
    @ObservedObject var viewModel: ConnectionInboxViewModel
    let onSelectPeer: (User) -> Void
    let onReport: (String, String) -> Void
    let onBlock: (String, String) -> Void

    var body: some View {
        Group {
            switch viewModel.incomingState {
            case .idle, .loading:
                ProgressView("Loading requests…")
                    .tint(CLColor.primary)
                    .foregroundStyle(CLColor.inkMuted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .empty:
                emptyState
            case let .error(message):
                errorState(message)
            case let .loaded(items):
                list(items)
            }
        }
        .clCanvasBackground()
        .navigationTitle("Liked you")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var emptyState: some View {
        CLEmptyState(
            systemImage: "heart",
            title: "No pending requests",
            message: "When someone wants to connect, they’ll show up here."
        )
    }

    private func errorState(_ message: String) -> some View {
        CLEmptyState(
            systemImage: "exclamationmark.triangle",
            title: message,
            systemImageColor: CLColor.error,
            actionTitle: "Retry",
            actionAccessibilityLabel: "Retry loading requests",
            titleAccessibilityLabel: "Error: \(message)"
        ) {
            Task { await viewModel.load() }
        }
    }

    private func list(_ items: [ConnectRequestItem]) -> some View {
        ScrollView {
            LazyVStack(spacing: CLSpacing.md) {
                ForEach(items) { item in
                    IncomingRequestCardView(
                        item: item,
                        isResponding: viewModel.respondingRequestId == item.id,
                        onAccept: {
                            Task {
                                await viewModel.accept(
                                    requestId: item.request.id,
                                    fromUserId: item.request.fromUserId
                                )
                            }
                        },
                        onDecline: {
                            Task { await viewModel.decline(requestId: item.request.id) }
                        },
                        onSelectPeer: { onSelectPeer(item.peer) }
                    )
                    .contextMenu {
                        Button("Report…") {
                            onReport(item.peer.id, item.peer.displayName)
                        }
                        Button("Block…", role: .destructive) {
                            onBlock(item.peer.id, item.peer.displayName)
                        }
                    }
                    .clAppear()
                }
            }
            .padding(.horizontal, CLSpacing.md)
            .padding(.vertical, CLSpacing.md)
        }
    }
}

// MARK: - Card

struct IncomingRequestCardView: View {
    let item: ConnectRequestItem
    let isResponding: Bool
    let onAccept: () -> Void
    let onDecline: () -> Void
    let onSelectPeer: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: CLSpacing.sm) {
            Button(action: onSelectPeer) {
                HStack(spacing: CLSpacing.sm) {
                    AvatarImageView(
                        localPreview: nil,
                        avatarBase64: item.peer.avatarBase64,
                        avatarURL: item.peer.avatarURL,
                        size: 56
                    )

                    VStack(alignment: .leading, spacing: CLSpacing.xxs) {
                        Text(item.peer.displayName)
                            .font(CLTypography.headline)
                            .foregroundStyle(CLColor.ink)

                        if !item.peer.interests.isEmpty {
                            Text(item.peer.interests.prefix(3).joined(separator: " · "))
                                .font(CLTypography.footnote)
                                .foregroundStyle(CLColor.inkMuted)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(CLColor.inkMuted)
                        .accessibilityHidden(true)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("View profile of \(item.peer.displayName)")

            HStack(spacing: CLSpacing.sm) {
                Button(action: onDecline) {
                    if isResponding {
                        ProgressView()
                            .tint(CLColor.ink)
                    } else {
                        Text("Decline")
                    }
                }
                .buttonStyle(CLSecondaryButtonStyle())
                .disabled(isResponding)
                .accessibilityLabel("Decline \(item.peer.displayName)")

                Button(action: onAccept) {
                    if isResponding {
                        ProgressView()
                            .tint(CLColor.onPrimary)
                    } else {
                        Text("Accept")
                    }
                }
                .buttonStyle(CLPrimaryButtonStyle())
                .disabled(isResponding)
                .accessibilityLabel("Accept \(item.peer.displayName)")
            }
        }
        .clCardStyle()
    }
}
