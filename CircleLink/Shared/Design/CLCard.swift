import SwiftUI

/// Soft Orbit card container — white surface on blush canvas, ~20pt radius, light shadow.
///
/// Prefer this when you want padding + card chrome in one place.
/// For custom layouts, use `.clCardStyle()` on an existing view instead.
struct CLCard<Content: View>: View {
    private let padded: Bool
    private let content: Content

    init(padded: Bool = true, @ViewBuilder content: () -> Content) {
        self.padded = padded
        self.content = content()
    }

    var body: some View {
        content
            .clCardStyle(padded: padded)
    }
}

#Preview("CLCard") {
    CLCard {
        VStack(alignment: .leading, spacing: CLSpacing.sm) {
            Text("Soft Orbit card")
                .font(CLTypography.section)
                .foregroundStyle(CLColor.ink)
            Text("White plate on blush canvas.")
                .font(CLTypography.callout)
                .foregroundStyle(CLColor.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(CLSpacing.lg)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(CLColor.canvas)
}
