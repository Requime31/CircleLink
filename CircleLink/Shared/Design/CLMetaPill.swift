import SwiftUI

/// Display-only Soft Orbit meta pill (interest tags, status chips).
/// Not interactive — use `CLInterestChip` when the user can toggle selection.
struct CLMetaPill: View {
    let title: String
    var emphasizesBrand: Bool = true

    var body: some View {
        Text(title)
            .font(CLTypography.caption.weight(.medium))
            .foregroundStyle(emphasizesBrand ? CLColor.primary : CLColor.ink)
            .padding(.horizontal, CLSpacing.md)
            .padding(.vertical, CLSpacing.xs + 2)
            .background(emphasizesBrand ? CLColor.companionSoft : CLColor.surfaceSoft)
            .clipShape(Capsule(style: .continuous))
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(
                        emphasizesBrand ? CLColor.primary.opacity(0.25) : CLColor.hairline,
                        lineWidth: 1
                    )
            )
    }
}

#Preview("Meta pills") {
    HStack {
        CLMetaPill(title: "Coffee")
        CLMetaPill(title: "Connected", emphasizesBrand: false)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(CLColor.canvas)
}
