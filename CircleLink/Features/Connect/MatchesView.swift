import SwiftUI

/// Accepted matches — Open Chat lives here (Accept never auto-opens chat).
struct MatchesView: View {
    @ObservedObject var viewModel: MatchesViewModel
    let onSelectPeer: (User) -> Void
    let onReport: (String, String) -> Void
    let onBlock: (String, String) -> Void

    var body: some View {
        Group {
            switch viewModel.matchedState {
            case .idle, .loading:
                ProgressView("Loading matches…")
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
        .navigationTitle("Matches")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var emptyState: some View {
        VStack(spacing: CLSpacing.md) {
            Image(systemName: "link")
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(CLColor.inkMuted)
                .accessibilityHidden(true)
            Text("No matches yet")
                .font(CLTypography.title2)
                .foregroundStyle(CLColor.ink)
            Text("Accept someone from Liked you, or connect from Discover.")
                .font(CLTypography.subheadline)
                .foregroundStyle(CLColor.inkMuted)
                .multilineTextAlignment(.center)
        }
        .padding(CLSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorState(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: CLSpacing.xs) {
            Text(message)
                .font(CLTypography.subheadline)
                .foregroundStyle(CLColor.inkSecondary)
            Button("Retry") {
                Task { await viewModel.load() }
            }
            .font(CLTypography.subheadline.weight(.medium))
            .foregroundStyle(CLColor.primaryPressed)
            .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
        }
        .padding(CLSpacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
                    .clAppear()
                }
            }
            .padding(.horizontal, CLSpacing.md)
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
