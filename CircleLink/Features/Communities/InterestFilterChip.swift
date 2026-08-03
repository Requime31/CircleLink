import SwiftUI

struct InterestFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(CLTypography.subheadline)
                .foregroundStyle(isSelected ? CLColor.ink : CLColor.inkSecondary)
                .padding(.horizontal, CLSpacing.sm)
                .padding(.vertical, CLSpacing.xs)
                .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
                .background(isSelected ? CLColor.primarySoft : CLColor.surfaceSoft)
                .clipShape(Capsule(style: .continuous))
                .scaleEffect(isSelected && !reduceMotion ? 1.02 : 1)
        }
        .buttonStyle(.plain)
        .clSoftSpring(value: isSelected)
        .accessibilityLabel(title == "All" ? "All interests" : "\(title) interest")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint("Double tap to filter communities")
    }
}
