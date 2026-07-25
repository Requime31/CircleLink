import SwiftUI

/// Soft Orbit “living node” interest chip.
///
/// Dumb UI only — selection state lives in the caller (View / ViewModel).
/// Selected = warm companion wash + Rausch text/stroke (style B).
struct CLInterestChip: View {
    let title: String
    let isSelected: Bool
    var isDisabled: Bool = false
    var accessibilityName: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(CLTypography.buttonSmall)
                .foregroundStyle(foreground)
                .multilineTextAlignment(.center)
                .padding(.horizontal, CLSpacing.md)
                .padding(.vertical, CLSpacing.sm)
                .frame(
                    minWidth: AccessibilityHelpers.minimumTouchTarget,
                    minHeight: AccessibilityHelpers.minimumTouchTarget
                )
                .background(fill)
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(border, lineWidth: isSelected ? 1.5 : 1)
                )
                .clipShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled && !isSelected ? 0.45 : 1)
        .clSoftSpring(value: isSelected)
        .accessibilityLabel(accessibilityName ?? "\(title) interest")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(isDisabled ? "Maximum interests selected" : "Double tap to toggle")
    }

    private var fill: Color {
        isSelected ? CLColor.companionSoft : CLColor.surfaceSoft
    }

    private var foreground: Color {
        isSelected ? CLColor.primary : CLColor.ink
    }

    private var border: Color {
        isSelected ? CLColor.primary : CLColor.hairline
    }
}

#Preview("Interest chips") {
    FlowPreview()
}

private struct FlowPreview: View {
    @State private var selected = Set(["Coffee", "Hiking"])

    private let interests = ["Coffee", "Hiking", "Music", "Art", "Food"]

    var body: some View {
        VStack(alignment: .leading, spacing: CLSpacing.md) {
            ForEach(interests, id: \.self) { interest in
                CLInterestChip(
                    title: interest,
                    isSelected: selected.contains(interest)
                ) {
                    if selected.contains(interest) {
                        selected.remove(interest)
                    } else {
                        selected.insert(interest)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(CLColor.canvas)
    }
}
