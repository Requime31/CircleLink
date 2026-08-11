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
                emptyState
            case let .error(message):
                errorState(message)
            case let .loaded(items):
                grid(items)
            }
        }
        .clCanvasBackground()
        .navigationTitle("Liked You")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var emptyState: some View {
        VStack(spacing: CLSpacing.md) {
            Image(systemName: "heart")
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(CLColor.inkMuted)
                .accessibilityHidden(true)
            Text("No pending requests")
                .font(CLTypography.title2)
                .foregroundStyle(CLColor.ink)
            Text("When someone wants to connect, they’ll show up here.")
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
            .padding(.horizontal, CLSpacing.md)
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
            .overlay(alignment: .topTrailing) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(.white.opacity(0.2))
                    .clipShape(Circle())
                    .padding(CLSpacing.sm)
                    .accessibilityHidden(true)
            }
            .clipShape(RoundedRectangle(cornerRadius: CLRadius.xl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CLRadius.xl, style: .continuous)
                    .stroke(CLColor.hairline, lineWidth: 1)
            )
            .shadow(color: CLShadow.cardColor, radius: CLShadow.cardRadius, x: 0, y: CLShadow.cardY)
    }
}
