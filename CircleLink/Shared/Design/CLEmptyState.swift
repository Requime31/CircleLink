import SwiftUI

/// Shared empty / soft-error placeholder for list screens.
/// Soft Orbit: warm companion well behind the icon; Rausch primary action.
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
                .font(.largeTitle.weight(.regular))
                .foregroundStyle(CLColor.muted)
                .padding(CLSpacing.base)
                .background(
                    Circle()
                        .fill(CLColor.companionSoft)
                )
                .accessibilityHidden(true)

            Text(title)
                .font(CLTypography.title2)
                .foregroundStyle(CLColor.ink)
                .multilineTextAlignment(.center)
                .accessibilityLabel(titleAccessibilityLabel ?? title)

            if let message {
                Text(message)
                    .font(CLTypography.callout)
                    .foregroundStyle(CLColor.muted)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(CLTypography.buttonSmall)
                    .buttonStyle(.borderedProminent)
                    .tint(CLColor.primary)
                    .padding(.top, CLSpacing.xs)
                    .accessibilityMinTouchTarget()
                    .accessibilityLabel(actionAccessibilityLabel ?? actionTitle)
            }
        }
        .padding(CLSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clAppear()
    }
}

#Preview("Empty state") {
    CLEmptyState(
        systemImage: "bubble.left.and.bubble.right",
        title: "No chats yet",
        message: "Match with someone to start a conversation.",
        actionTitle: "Find people"
    ) {}
    .background(CLColor.canvas)
}
