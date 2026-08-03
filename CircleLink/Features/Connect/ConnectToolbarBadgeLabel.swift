import SwiftUI

/// Toolbar icon with an optional numeric badge (Liked you / Matches).
struct ConnectToolbarBadgeLabel: View {
    let title: String
    let systemImage: String
    let badge: Int

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(CLColor.ink)
                .frame(minWidth: 28, minHeight: AccessibilityHelpers.minimumTouchTarget)

            if badge > 0 {
                Text(badge > 99 ? "99+" : "\(badge)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(CLColor.onPrimary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(CLColor.primary)
                    .clipShape(Capsule())
                    .offset(x: 8, y: -4)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
    }
}
