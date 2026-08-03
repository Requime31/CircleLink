import SwiftUI

/// Community menu for Connect Discover.
struct ConnectCommunityPickerSection: View {
    @ObservedObject var discovery: ConnectDiscoveryViewModel
    let onRetryLoad: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: CLSpacing.sm) {
            Text("Community")
                .font(CLTypography.headline)
                .foregroundStyle(CLColor.ink)

            switch discovery.communitiesState {
            case .idle, .loading:
                ProgressView("Loading communities…")
                    .tint(CLColor.primary)
                    .foregroundStyle(CLColor.inkMuted)
            case .empty:
                Text("Join a community first to find people.")
                    .font(CLTypography.subheadline)
                    .foregroundStyle(CLColor.inkMuted)
            case let .error(message):
                ConnectSectionError(message: message, retry: onRetryLoad)
            case let .loaded(communities):
                Menu {
                    ForEach(communities) { community in
                        Button(community.name) {
                            Task { await discovery.selectCommunity(community.id) }
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedCommunityName(from: communities))
                            .font(CLTypography.body.weight(.medium))
                            .foregroundStyle(CLColor.ink)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(CLColor.inkMuted)
                            .accessibilityHidden(true)
                    }
                    .padding(.horizontal, CLSpacing.md)
                    .frame(height: 48)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(CLColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous)
                            .stroke(CLColor.hairline, lineWidth: 1)
                    )
                }
                .accessibilityLabel("Select community")
            }
        }
    }

    private func selectedCommunityName(from communities: [Community]) -> String {
        communities.first(where: { $0.id == discovery.selectedCommunityId })?.name
            ?? "Select community"
    }
}
