import SwiftUI

/// Discover swipe-deck section for the Connect tab.
struct ConnectDeckSection: View {
    @ObservedObject var discovery: ConnectDiscoveryViewModel
    let onViewProfile: (User) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: CLSpacing.sm) {
            Text("Discover")
                .font(CLTypography.headline)
                .foregroundStyle(CLColor.ink)

            if discovery.selectedCommunityId == nil {
                Text("Select a community to see people.")
                    .font(CLTypography.subheadline)
                    .foregroundStyle(CLColor.inkMuted)
            } else {
                switch discovery.candidatesState {
                case .idle, .loading:
                    ProgressView("Loading people…")
                        .tint(CLColor.primary)
                        .foregroundStyle(CLColor.inkMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, CLSpacing.xl)
                case .empty:
                    deckEmpty(
                        title: "No one new here",
                        message: "Check another community, or come back later."
                    )
                case let .error(message):
                    ConnectSectionError(message: message) {
                        if let communityId = discovery.selectedCommunityId {
                            Task { await discovery.selectCommunity(communityId) }
                        }
                    }
                case .loaded:
                    if let top = discovery.topCandidate {
                        let underlay = discovery.deckCandidates.dropFirst().first
                        ConnectDiscoverDeckView(
                            top: top,
                            underlay: underlay,
                            onPass: {
                                withAnimation(CLMotion.soft) {
                                    discovery.passCandidate(userId: top.id)
                                }
                            },
                            onViewProfile: { onViewProfile(top) }
                        )
                        .clAppear()
                    } else {
                        deckEmpty(
                            title: "You’re all caught up",
                            message: "Pull to refresh, or pick another community."
                        )
                    }
                }
            }
        }
    }

    private func deckEmpty(title: String, message: String) -> some View {
        VStack(spacing: CLSpacing.sm) {
            Image(systemName: "person.2")
                .font(.system(size: 36, weight: .regular))
                .foregroundStyle(CLColor.inkMuted)
                .accessibilityHidden(true)
            Text(title)
                .font(CLTypography.title2)
                .foregroundStyle(CLColor.ink)
                .multilineTextAlignment(.center)
            Text(message)
                .font(CLTypography.subheadline)
                .foregroundStyle(CLColor.inkMuted)
                .multilineTextAlignment(.center)
        }
        .padding(CLSpacing.lg)
        .frame(maxWidth: .infinity)
        .background(CLColor.surfaceSoft)
        .clipShape(RoundedRectangle(cornerRadius: CLRadius.lg, style: .continuous))
    }
}
