import SwiftUI

/// Shared empty / soft-error placeholder for list screens.
/// Keeps icon + title + optional message + optional primary action consistent.
struct CLEmptyState: View {
    let systemImage: String
    let title: String
    var message: String?
    /// Defaults to muted ink; pass `CLColor.error` for soft-error screens.
    var systemImageColor: Color = CLColor.inkMuted
    var actionTitle: String?
    var actionAccessibilityLabel: String?
    var titleAccessibilityLabel: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: CLSpacing.md) {
            Image(systemName: systemImage)
                .font(.system(size: 48, weight: .regular))
                .foregroundStyle(systemImageColor)
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
