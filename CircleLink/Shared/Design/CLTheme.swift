import SwiftUI

/// Soft Orbit Social design tokens for CircleLink.
/// Adapted from `DESIGN.md` (Rausch + soft shapes) with a warm blush canvas —
/// not Airbnb pure-white. SF Pro only; Dynamic Type via semantic fonts.
/// Light mode only (no dark palette).
enum CLColor {
    // MARK: Brand

    /// Rausch `#ff385c` — primary CTAs and brand voltage.
    static let primary = Color(red: 1.0, green: 0.22, blue: 0.36)
    /// Pressed primary `#e00b41`.
    static let primaryActive = Color(red: 0.878, green: 0.043, blue: 0.255)
    /// Disabled primary `#ffd1da`.
    static let primaryDisabled = Color(red: 1.0, green: 0.820, blue: 0.855)
    /// Warm apricot companion `#F4A261` — sits next to Rausch (no purple / neon).
    static let companion = Color(red: 0.957, green: 0.635, blue: 0.380)
    /// Soft apricot wash `#FFE8D6` — chip selected fill, soft accent wells.
    static let companionSoft = Color(red: 1.0, green: 0.910, blue: 0.839)
    /// Form / inline error `#c13515` (distinct from Rausch).
    static let error = Color(red: 0.757, green: 0.208, blue: 0.082)

    // MARK: Text

    /// Near-black `#222222` for titles and primary text.
    static let ink = Color(red: 0.133, green: 0.133, blue: 0.133)
    /// Secondary body `#3f3f3f`.
    static let body = Color(red: 0.247, green: 0.247, blue: 0.247)
    /// Muted `#6a6a6a` for subtitles and meta.
    static let muted = Color(red: 0.416, green: 0.416, blue: 0.416)
    /// Soft muted `#929292`.
    static let mutedSoft = Color(red: 0.573, green: 0.573, blue: 0.573)

    // MARK: Lines

    /// Warm hairline `#E8D9D2`.
    static let hairline = Color(red: 0.910, green: 0.851, blue: 0.824)
    /// Softer warm hairline `#F0E6E1`.
    static let hairlineSoft = Color(red: 0.941, green: 0.902, blue: 0.882)

    // MARK: Surfaces

    /// Soft blush page floor `#FFF6F2` (not pure white).
    static let canvas = Color(red: 1.0, green: 0.965, blue: 0.949)
    /// Card surface `#FFFFFF` — lifts content off the blush canvas.
    static let surfaceCard = Color.white
    /// Soft peach fill `#FFF0EA` — unselected chips, fields.
    static let surfaceSoft = Color(red: 1.0, green: 0.941, blue: 0.918)
    /// Stronger peach fill `#F5E4DC`.
    static let surfaceStrong = Color(red: 0.961, green: 0.894, blue: 0.863)
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
    /// Fields / compact controls.
    static let sm: CGFloat = 8
    /// Nested / compact cards (~16).
    static let md: CGFloat = 16
    /// Default Soft Orbit cards (~20).
    static let lg: CGFloat = 20
    /// Pills, chips, circles.
    static let full: CGFloat = 9999
}

/// Single soft elevation tier for cards.
enum CLShadow {
    static let cardColor = Color.black.opacity(0.06)
    static let cardRadius: CGFloat = 12
    static let cardY: CGFloat = 4
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

/// Reusable Soft Orbit motion — soft spring only, no bounce circus.
enum CLMotion {
    static let softSpring = Animation.spring(response: 0.45, dampingFraction: 0.82)
}

// MARK: - Field chrome

extension View {
    /// Soft field surface for text inputs (warm Soft Orbit chrome).
    func clTextFieldChrome() -> some View {
        padding(CLSpacing.md)
            .background(CLColor.surfaceSoft)
            .clipShape(RoundedRectangle(cornerRadius: CLRadius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CLRadius.sm, style: .continuous)
                    .stroke(CLColor.hairline, lineWidth: 1)
            )
    }

    /// Applies the shared soft spring when `value` changes.
    func clSoftSpring<V: Equatable>(value: V) -> some View {
        animation(CLMotion.softSpring, value: value)
    }

    /// Soft appear: fade + slight scale/offset on first appearance.
    func clAppear(delay: Double = 0) -> some View {
        modifier(CLAppearModifier(delay: delay))
    }

    /// Soft Orbit card surface: white plate, ~20pt radius, light shadow.
    func clCardStyle(padded: Bool = false) -> some View {
        modifier(CLCardStyleModifier(padded: padded))
    }
}

// MARK: - Appear

private struct CLAppearModifier: ViewModifier {
    var delay: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared || reduceMotion ? 1 : 0.96)
            .offset(y: appeared || reduceMotion ? 0 : 8)
            .onAppear {
                guard !appeared else { return }
                if reduceMotion {
                    appeared = true
                } else {
                    withAnimation(CLMotion.softSpring.delay(delay)) {
                        appeared = true
                    }
                }
            }
    }
}

// MARK: - Card style

private struct CLCardStyleModifier: ViewModifier {
    var padded: Bool

    func body(content: Content) -> some View {
        content
            .padding(padded ? CLSpacing.base : 0)
            .background(CLColor.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: CLRadius.lg, style: .continuous))
            .shadow(
                color: CLShadow.cardColor,
                radius: CLShadow.cardRadius,
                x: 0,
                y: CLShadow.cardY
            )
    }
}
