import SwiftUI

/// Scroll body for Connect Discover: status banners + community picker + deck.
struct ConnectDiscoverContent: View {
    @ObservedObject var tab: ConnectTabModel
    let onViewProfile: (User) -> Void

    private var discovery: ConnectDiscoveryViewModel { tab.discovery }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CLSpacing.lg) {
                if let blockedUsersErrorMessage = tab.blockedUsersErrorMessage {
                    blockFilterBanner(message: blockedUsersErrorMessage)
                }

                if let actionErrorMessage = tab.actionErrorMessage {
                    Text(actionErrorMessage)
                        .font(CLTypography.footnote)
                        .foregroundStyle(CLColor.error)
                        .padding(CLSpacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(CLColor.errorSoft)
                        .clipShape(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous))
                        .accessibilityLabel("Connect error: \(actionErrorMessage)")
                }

                if let moderationMessage = tab.moderationMessage {
                    Text(moderationMessage)
                        .font(CLTypography.footnote)
                        .foregroundStyle(CLColor.inkSecondary)
                        .padding(CLSpacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(CLColor.surfaceSoft)
                        .clipShape(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous))
                        .onTapGesture { tab.clearModerationFeedback() }
                }

                if !tab.isBlockFilterReady && tab.blockedUsersErrorMessage == nil {
                    HStack(spacing: CLSpacing.sm) {
                        ProgressView()
                            .tint(CLColor.primary)
                        Text("Checking blocked profiles…")
                            .font(CLTypography.subheadline)
                            .foregroundStyle(CLColor.inkSecondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 80)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Checking blocked profiles")
                }

                if tab.isBlockFilterReady {
                    ConnectCommunityPickerSection(
                        discovery: discovery,
                        onRetryLoad: { Task { await tab.load() } }
                    )
                    ConnectDeckSection(
                        discovery: discovery,
                        onViewProfile: onViewProfile
                    )
                }
            }
            .padding(.horizontal, CLSpacing.md)
            .padding(.vertical, CLSpacing.md)
        }
    }

    private func blockFilterBanner(message: String) -> some View {
        HStack(alignment: .top, spacing: CLSpacing.sm) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(CLColor.inkSecondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: CLSpacing.xxs) {
                Text(blockFilterWarningTitle)
                    .font(CLTypography.footnote.weight(.semibold))
                    .foregroundStyle(CLColor.ink)
                Text(message)
                    .font(CLTypography.caption)
                    .foregroundStyle(CLColor.inkSecondary)
                    .lineLimit(2)
                Button("Retry") {
                    Task { await tab.load() }
                }
                .font(CLTypography.footnote.weight(.medium))
                .foregroundStyle(CLColor.primaryPressed)
                .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
            }
        }
        .padding(CLSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CLColor.tintCream)
        .clipShape(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous))
    }

    private var blockFilterWarningTitle: String {
        if tab.isBlockFilterReady {
            return "Blocked profiles may be out of date."
        }
        return "Connect is unavailable until blocked profiles can be checked."
    }
}
