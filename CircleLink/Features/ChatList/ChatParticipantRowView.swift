import SwiftUI

struct ChatParticipantRowView: View {
    static let avatarSize: CGFloat = 44

    let user: User
    var subtitle: String?
    var showsChevron: Bool = true

    var body: some View {
        HStack(spacing: CLSpacing.sm) {
            AvatarImageView(
                localPreview: nil,
                avatarBase64: user.avatarBase64,
                avatarURL: user.avatarURL,
                size: Self.avatarSize
            )

            VStack(alignment: .leading, spacing: CLSpacing.xxs) {
                Text(user.displayName.isEmpty ? "Member" : user.displayName)
                    .font(CLTypography.headline)
                    .foregroundStyle(CLColor.ink)

                if let subtitle {
                    Text(subtitle)
                        .font(CLTypography.caption)
                        .foregroundStyle(CLColor.inkMuted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CLColor.inkMuted)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, CLSpacing.xxs)
        .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
        .contentShape(Rectangle())
    }
}
