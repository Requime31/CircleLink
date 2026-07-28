import SwiftUI

/// CircleLink design tokens adapted from `DESIGN.md` for SwiftUI.
/// Uses SF Pro (system) instead of Airbnb Cereal; keeps Rausch primary + soft radii.
enum CLColor {
    /// Rausch `#ff385c` — primary CTAs and brand accents.
    static let primary = Color(red: 1.0, green: 0.22, blue: 0.36)
    /// Pressed primary `#e00b41`.
    static let primaryActive = Color(red: 0.878, green: 0.043, blue: 0.255)
    /// Disabled primary `#ffd1da`.
    static let primaryDisabled = Color(red: 1.0, green: 0.820, blue: 0.855)
    /// Form / inline error `#c13515` (not the same as primary).
    static let error = Color(red: 0.757, green: 0.208, blue: 0.082)

    /// Near-black `#222222` for titles and primary text.
    static let ink = Color(red: 0.133, green: 0.133, blue: 0.133)
    /// Secondary body `#3f3f3f`.
    static let body = Color(red: 0.247, green: 0.247, blue: 0.247)
    /// Muted `#6a6a6a` for subtitles and meta.
    static let muted = Color(red: 0.416, green: 0.416, blue: 0.416)
    /// Soft muted `#929292`.
    static let mutedSoft = Color(red: 0.573, green: 0.573, blue: 0.573)

    /// Default hairline `#dddddd`.
    static let hairline = Color(red: 0.867, green: 0.867, blue: 0.867)
    /// Soft hairline `#ebebeb`.
    static let hairlineSoft = Color(red: 0.922, green: 0.922, blue: 0.922)

    /// Page canvas `#ffffff`.
    static let canvas = Color.white
    /// Soft fill `#f7f7f7` — cards, chips, fields.
    static let surfaceSoft = Color(red: 0.969, green: 0.969, blue: 0.969)
    /// Stronger fill `#f2f2f2`.
    static let surfaceStrong = Color(red: 0.949, green: 0.949, blue: 0.949)
    /// Text on primary CTAs.
    static let onPrimary = Color.white
}

enum CLSpacing {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let base: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

enum CLRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 14
    static let lg: CGFloat = 20
    static let full: CGFloat = 9999
}

/// Brand type mapped onto Dynamic Type text styles so Larger Text still works.
enum CLTypography {
    static let display = Font.largeTitle.weight(.bold)
    static let title = Font.title2.weight(.semibold)
    static let title2 = Font.title3.weight(.semibold)
    static let section = Font.headline.weight(.semibold)
    static let body = Font.body
    static let bodyMedium = Font.body.weight(.medium)
    static let callout = Font.subheadline
    static let caption = Font.footnote
    static let button = Font.body.weight(.medium)
    static let buttonSmall = Font.subheadline.weight(.medium)
}

// MARK: - Field chrome

extension View {
    /// Soft field surface matching DESIGN `text-input` (adapted for iOS).
    func clTextFieldChrome() -> some View {
        padding(CLSpacing.md)
            .background(CLColor.surfaceSoft)
            .clipShape(RoundedRectangle(cornerRadius: CLRadius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: CLRadius.sm)
                    .stroke(CLColor.hairline, lineWidth: 1)
            )
    }
}
