import SwiftUI

/// Read-only mirror of public fields — same visual language as peer profile.
struct ProfilePublicCardView: View {
    let user: User
    let localAvatarPreview: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: CLSpacing.md) {
            VStack(alignment: .leading, spacing: CLSpacing.xxs) {
                Text("How others see you")
                    .font(CLTypography.headline)
                    .foregroundStyle(CLColor.ink)

                Text("This is what people see when they open your card.")
                    .font(CLTypography.footnote)
                    .foregroundStyle(CLColor.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(alignment: .top, spacing: CLSpacing.md) {
                AvatarImageView(
                    localPreview: localAvatarPreview,
                    avatarBase64: user.avatarBase64,
                    avatarURL: user.avatarURL,
                    size: 64
                )
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: CLSpacing.xs) {
                    Text(displayName)
                        .font(CLTypography.title2)
                        .foregroundStyle(CLColor.ink)
                        .accessibilityHidden(true)

                    publicInterests(user.interests)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clCardStyle()
        .overlay(
            RoundedRectangle(cornerRadius: CLRadius.lg, style: .continuous)
                .stroke(CLColor.hairline, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private func publicInterests(_ interests: [String]) -> some View {
        if interests.isEmpty {
            Text("No interests yet")
                .font(CLTypography.subheadline)
                .foregroundStyle(CLColor.inkMuted)
        } else {
            FlowLayout(spacing: CLSpacing.xs) {
                ForEach(interests, id: \.self) { interest in
                    Text(interest)
                        .font(CLTypography.caption)
                        .foregroundStyle(CLColor.inkSecondary)
                        .padding(.horizontal, CLSpacing.sm)
                        .padding(.vertical, CLSpacing.xxs)
                        .background(CLColor.surfaceSoft)
                        .clipShape(Capsule())
                }
            }
        }
    }

    private var displayName: String {
        user.displayName.isEmpty ? "Member" : user.displayName
    }

    private var accessibilityLabel: String {
        let interests = user.interests.isEmpty
            ? "No interests yet"
            : "Interests: \(user.interests.joined(separator: ", "))"
        // Name is already announced in the hero — avoid VoiceOver duplication.
        return "How others see you. \(interests)"
    }
}
