import SwiftUI
import UIKit

/// Personal cabinet identity: soft atmosphere + avatar + name.
struct ProfileHeroView: View {
    let user: User
    let localAvatarPreview: UIImage?

    var body: some View {
        VStack(spacing: CLSpacing.md) {
            AvatarImageView(
                localPreview: localAvatarPreview,
                avatarBase64: user.avatarBase64,
                avatarURL: user.avatarURL,
                size: 112
            )
            .accessibilityLabel("Profile photo")
            .overlay(
                Circle()
                    .stroke(CLColor.surface.opacity(0.9), lineWidth: 3)
            )

            VStack(spacing: CLSpacing.xxs) {
                Text(displayName)
                    .font(CLTypography.title)
                    .foregroundStyle(CLColor.ink)
                    .multilineTextAlignment(.center)
                    .accessibilityLabel("Display name: \(displayName)")

                Text("Your profile")
                    .font(CLTypography.subheadline)
                    .foregroundStyle(CLColor.inkMuted)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, CLSpacing.lg)
        .padding(.top, CLSpacing.xl)
        .padding(.bottom, CLSpacing.xl)
        .background {
            LinearGradient(
                colors: [
                    CLColor.tintCream,
                    CLColor.primarySoft.opacity(0.55),
                    CLColor.canvas
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
        }
    }

    private var displayName: String {
        user.displayName.isEmpty ? "Member" : user.displayName
    }
}
