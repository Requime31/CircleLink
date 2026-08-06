import SwiftUI

/// Shared empty / soft-error placeholder for list screens.
/// Keeps icon + title + optional message + optional primary action consistent.
struct CLEmptyState: View {
    let systemImage: String
    let title: String
    var message: String? = nil
    var actionTitle: String? = nil
    var actionAccessibilityLabel: String? = nil
    var titleAccessibilityLabel: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: CLSpacing.md) {
            Image(systemName: systemImage)
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(CLColor.inkMuted)
                .frame(width: 72, height: 72)
                .background(CLColor.surfaceSoft)
                .clipShape(RoundedRectangle(cornerRadius: CLRadius.lg, style: .continuous))
                .accessibilityHidden(true)

            Text(title)
                .font(CLTypography.title2)
                .foregroundStyle(CLColor.ink)
                .multilineTextAlignment(.center)
                .accessibilityLabel(titleAccessibilityLabel ?? title)

            if let message {
                Text(message)
                    .font(CLTypography.callout)
                    .foregroundStyle(CLColor.inkMuted)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(CLTypography.button)
                    .buttonStyle(CLPrimaryButtonStyle(fillsWidth: false))
                    .padding(.top, CLSpacing.xs)
                    .accessibilityLabel(actionAccessibilityLabel ?? actionTitle)
            }
        }
        .padding(CLSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
