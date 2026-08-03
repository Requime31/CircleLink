import SwiftUI

/// Name + interest + count — soft hub anchor for community detail.
struct CommunityDetailHeaderSection: View {
    let community: Community

    var body: some View {
        VStack(alignment: .leading, spacing: CLSpacing.sm) {
            Text(community.name)
                .font(CLTypography.title)
                .foregroundStyle(CLColor.ink)
                .accessibilityAddTraits(.isHeader)

            Text(community.interestTag)
                .font(CLTypography.caption)
                .foregroundStyle(CLColor.ink)
                .padding(.horizontal, CLSpacing.sm)
                .padding(.vertical, CLSpacing.xxs)
                .background(CLColor.primarySoft)
                .clipShape(Capsule())
                .accessibilityLabel("Interest: \(community.interestTag)")

            Text(memberCountLabel(for: community.memberCount))
                .font(CLTypography.footnote)
                .foregroundStyle(CLColor.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func memberCountLabel(for count: Int) -> String {
        count == 1 ? "1 member" : "\(count) members"
    }
}
