import SwiftUI

struct CommunityCardView: View {
    let community: Community

    var body: some View {
        VStack(alignment: .leading, spacing: CLSpacing.sm) {
            HStack(alignment: .top, spacing: CLSpacing.xs) {
                Text(community.name)
                    .font(CLTypography.title2)
                    .foregroundStyle(CLColor.ink)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: CLSpacing.xs)

                Text(community.interestTag)
                    .font(CLTypography.caption)
                    .foregroundStyle(CLColor.ink)
                    .padding(.horizontal, CLSpacing.sm)
                    .padding(.vertical, CLSpacing.xxs)
                    .background(CLColor.primarySoft)
                    .clipShape(Capsule())
            }

            Text(community.description)
                .font(CLTypography.subheadline)
                .foregroundStyle(CLColor.inkSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            HStack(spacing: CLSpacing.xs) {
                Image(systemName: "person.2.fill")
                    .font(.caption)
                    .foregroundStyle(CLColor.inkMuted)
                    .accessibilityHidden(true)
                Text(memberCountLabel)
                    .font(CLTypography.footnote)
                    .foregroundStyle(CLColor.inkMuted)

                Spacer(minLength: CLSpacing.xs)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(CLColor.inkDisabled)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .clCardStyle()
    }

    private var memberCountLabel: String {
        community.memberCount == 1 ? "1 member" : "\(community.memberCount) members"
    }
}
