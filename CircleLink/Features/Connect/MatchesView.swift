import SwiftUI

/// Accepted matches — Open Chat lives here (Accept never auto-opens chat).
struct MatchesView: View {
    @ObservedObject var viewModel: ConnectViewModel
    let onSelectPeer: (User) -> Void
    let onReport: (String, String) -> Void
    let onBlock: (String, String) -> Void

    var body: some View {
        Group {
            switch viewModel.matchedState {
            case .idle, .loading:
                CLLoadingState(message: "Loading matches…")
            case .empty:
                CLEmptyState(
                    systemImage: "link",
                    title: "No matches yet",
                    message: "Accept someone from Liked you, or connect from Discover."
                )
            case let .error(message):
                CLEmptyState(
                    systemImage: "exclamationmark.triangle",
                    title: "Couldn’t load matches",
                    message: message,
                    actionTitle: "Retry",
                    actionAccessibilityLabel: "Retry loading matches"
                ) {
                    Task { await viewModel.load() }
                }
            case let .loaded(items):
                list(items)
                    .clAppear()
            }
        }
        .clCanvasBackground()
        .navigationTitle("Matches")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func list(_ items: [MatchedConnectionItem]) -> some View {
        ScrollView {
            LazyVStack(spacing: CLSpacing.md) {
                ForEach(items) { item in
                    MatchedConnectionCardView(
                        item: item,
                        isOpening: viewModel.openingChatPeerId == item.peer.id,
                        onOpenChat: {
                            Task { await viewModel.openChat(with: item.peer.id) }
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
                }
            }
            .padding(.horizontal, CLSpacing.screenHorizontal)
            .padding(.vertical, CLSpacing.md)
        }
    }
}

// MARK: - Card

struct MatchedConnectionCardView: View {
    let item: MatchedConnectionItem
    let isOpening: Bool
    let onOpenChat: () -> Void
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

                        Text("Connected")
                            .font(CLTypography.footnote)
                            .foregroundStyle(CLColor.success)
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

            Button(action: onOpenChat) {
                if isOpening {
                    ProgressView()
                        .tint(CLColor.onPrimary)
                } else {
                    Text("Open Chat")
                }
            }
            .buttonStyle(CLPrimaryButtonStyle())
            .disabled(isOpening)
            .accessibilityLabel("Open chat with \(item.peer.displayName)")
        }
        .clCardStyle()
    }
}
