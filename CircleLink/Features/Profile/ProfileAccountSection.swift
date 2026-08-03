import SwiftUI

/// Settings entry + sign out for the owner's Profile tab.
struct ProfileAccountSection: View {
    let onOpenSettings: () -> Void
    let onSignOut: () -> Void

    var body: some View {
        VStack(spacing: CLSpacing.sm) {
            Text("Account")
                .font(CLTypography.caption)
                .foregroundStyle(CLColor.inkMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, CLSpacing.xxs)
                .accessibilityAddTraits(.isHeader)

            Button(action: onOpenSettings) {
                HStack(spacing: CLSpacing.sm) {
                    Image(systemName: "gearshape")
                        .font(.body.weight(.medium))
                        .foregroundStyle(CLColor.primaryPressed)
                        .frame(width: 28, alignment: .center)
                        .accessibilityHidden(true)

                    Text("Settings")
                        .font(CLTypography.body)
                        .foregroundStyle(CLColor.ink)

                    Spacer(minLength: CLSpacing.xs)

                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(CLColor.inkDisabled)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, CLSpacing.md)
                .padding(.vertical, CLSpacing.sm)
                .frame(maxWidth: .infinity, minHeight: AccessibilityHelpers.minimumTouchTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(CLColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: CLRadius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CLRadius.lg, style: .continuous)
                    .stroke(CLColor.hairline, lineWidth: 1)
            )
            .accessibilityLabel("Settings")
            .accessibilityHint("Opens notifications and about")

            LogoutButton(action: onSignOut)
                .frame(maxWidth: .infinity)
                .padding(.vertical, CLSpacing.sm)
                .background(CLColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: CLRadius.lg, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: CLRadius.lg, style: .continuous)
                        .stroke(CLColor.hairline, lineWidth: 1)
                )
        }
        .padding(.top, CLSpacing.xl)
    }
}
