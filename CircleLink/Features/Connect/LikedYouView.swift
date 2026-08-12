import SwiftUI

/// Incoming Connect requests — grid of people who liked you.
struct LikedYouView: View {
    @ObservedObject var viewModel: ConnectViewModel
    let onSelectPeer: (ConnectRequestItem) -> Void
    let onReport: (String, String) -> Void
    let onBlock: (String, String) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: CLSpacing.md),
        GridItem(.flexible(), spacing: CLSpacing.md)
    ]

    var body: some View {
        Group {
            switch viewModel.incomingState {
            case .idle, .loading:
                ProgressView("Loading requests…")
                    .tint(CLColor.primary)
                    .foregroundStyle(CLColor.inkMuted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .empty:
                CLEmptyState(
                    systemImage: "heart",
                    title: "No pending requests",
                    message: "When someone wants to connect, they’ll show up here."
                )
            case let .error(message):
                CLEmptyState(
                    systemImage: "exclamationmark.triangle",
                    title: "Couldn’t load requests",
                    message: message,
                    actionTitle: "Retry",
                    actionAccessibilityLabel: "Retry loading requests"
                ) {
                    Task { await viewModel.load() }
                }
            case let .loaded(items):
                grid(items)
            }
        }
        .clCanvasBackground()
        .navigationTitle("Liked You")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func grid(_ items: [ConnectRequestItem]) -> some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: CLSpacing.md) {
                ForEach(items) { item in
                    Button {
                        onSelectPeer(item)
                    } label: {
                        LikedYouGridCard(user: item.peer)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Report…") {
                            onReport(item.peer.id, item.peer.displayName)
                        }
                        Button("Block…", role: .destructive) {
                            onBlock(item.peer.id, item.peer.displayName)
                        }
                    }
                    .accessibilityLabel("View profile of \(item.peer.displayNameWithAge)")
                }
            }
            .padding(.horizontal, CLSpacing.screenHorizontal)
            .padding(.vertical, CLSpacing.md)
        }
    }
}

// MARK: - Grid card

private struct LikedYouGridCard: View {
    let user: User

    var body: some View {
        // Fixed aspect box first — image fills via overlay so LazyVGrid stays stable.
        Color.clear
            .aspectRatio(3 / 4, contentMode: .fit)
            .overlay {
                ProfileHeroImageView(
                    avatarBase64: user.avatarBase64,
                    avatarURL: user.avatarURL
                )
            }
            .overlay {
                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.6)],
                    startPoint: .center,
                    endPoint: .bottom
                )
            }
            .overlay(alignment: .bottomLeading) {
                Text(user.displayNameWithAge)
                    .font(CLTypography.title2)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .padding(CLSpacing.md)
            }
            .clipShape(RoundedRectangle(cornerRadius: CLRadius.xl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CLRadius.xl, style: .continuous)
                    .stroke(CLColor.hairline, lineWidth: 1)
            )
    }
}
