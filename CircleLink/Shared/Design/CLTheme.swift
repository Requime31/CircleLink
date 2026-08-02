import SwiftUI

// CircleLink design tokens from local `DESIGN.md`.
// View chrome only — no Domain / networking.

// MARK: - Color

enum CLColor {
    // Surfaces
    static let canvas = Color(red: 0.980, green: 0.976, blue: 0.969)       // #FAF9F7
    static let surface = Color.white                                         // #FFFFFF
    static let surfaceSoft = Color(red: 0.961, green: 0.953, blue: 0.941)   // #F5F3F0
    static let hairline = Color(red: 0.910, green: 0.894, blue: 0.875)      // #E8E4DF
    static let hairlineStrong = Color(red: 0.831, green: 0.812, blue: 0.784) // #D4CFC8

    // Ink
    static let ink = Color(red: 0.102, green: 0.102, blue: 0.102)           // #1A1A1A
    static let inkSecondary = Color(red: 0.361, green: 0.341, blue: 0.310)  // #5C574F
    static let inkMuted = Color(red: 0.541, green: 0.518, blue: 0.478)      // #8A847A
    static let inkDisabled = Color(red: 0.722, green: 0.698, blue: 0.659)   // #B8B2A8

    // Primary (peach)
    static let primary = Color(red: 0.949, green: 0.651, blue: 0.541)       // #F2A68A
    static let primaryPressed = Color(red: 0.878, green: 0.545, blue: 0.424) // #E08B6C
    static let primarySoft = Color(red: 0.992, green: 0.910, blue: 0.871)   // #FDE8DE
    static let primaryStrong = Color(red: 0.910, green: 0.573, blue: 0.435) // #E8926F
    static let onPrimary = Color(red: 0.102, green: 0.102, blue: 0.102)     // #1A1A1A
    static let onPrimaryStrong = Color.white

    // Soft tints (communities / interests) — light use only
    static let tintCream = Color(red: 0.973, green: 0.945, blue: 0.906)     // #F8F1E7

    // Semantic
    static let error = Color(red: 0.851, green: 0.310, blue: 0.310)         // #D94F4F
    static let errorSoft = Color(red: 0.988, green: 0.918, blue: 0.918)     // #FCEAEA
    static let success = Color(red: 0.239, green: 0.608, blue: 0.431)       // #3D9B6E
}

// MARK: - Spacing / Radius / Shadow

enum CLSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

enum CLRadius {
    static let sm: CGFloat = 10
    static let md: CGFloat = 14
    static let lg: CGFloat = 18
    static let xl: CGFloat = 24
}

enum CLShadow {
    static let cardColor = Color.black.opacity(0.08)
    static let cardRadius: CGFloat = 16
    static let cardY: CGFloat = 6
}

// MARK: - Typography (SF Pro + Dynamic Type)

enum CLTypography {
    static let largeTitle = Font.system(.largeTitle, design: .default).weight(.semibold)
    static let title = Font.title2.weight(.semibold)
    static let title2 = Font.title3.weight(.semibold)
    static let headline = Font.headline.weight(.semibold)
    static let body = Font.body
    static let callout = Font.callout
    static let subheadline = Font.subheadline
    static let footnote = Font.footnote
    static let caption = Font.caption.weight(.medium)
    static let button = Font.body.weight(.medium)
}

// MARK: - Motion

enum CLMotion {
    static let soft = Animation.spring(response: 0.35, dampingFraction: 0.82)
    static let softLarge = Animation.spring(response: 0.45, dampingFraction: 0.86)
    static let micro = Animation.spring(response: 0.28, dampingFraction: 0.78)
}

// MARK: - Button styles

/// Peach fill + dark label. Disabled → soft surface + muted ink.
/// - `fillsWidth: true` (default) — full-width CTAs
/// - `fillsWidth: false` — compact row CTAs (avoids infinity + fixedSize NaN layout)
struct CLPrimaryButtonStyle: ButtonStyle {
    var fillsWidth: Bool = true

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CLTypography.button)
            .foregroundStyle(isEnabled ? CLColor.onPrimary : CLColor.inkDisabled)
            .padding(.horizontal, fillsWidth ? 0 : CLSpacing.md)
            .frame(maxWidth: fillsWidth ? .infinity : nil)
            .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
            .background(background(configuration.isPressed))
            .clipShape(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous))
            .opacity(configuration.isPressed && isEnabled ? 0.92 : 1)
            .scaleEffect(pressScale(configuration.isPressed))
            .animation(reduceMotion ? .easeOut(duration: 0.15) : CLMotion.micro, value: configuration.isPressed)
    }

    private func pressScale(_ pressed: Bool) -> CGFloat {
        guard isEnabled, pressed, !reduceMotion else { return 1 }
        return 0.98
    }

    private func background(_ pressed: Bool) -> Color {
        guard isEnabled else { return CLColor.surfaceSoft }
        return pressed ? CLColor.primaryPressed : CLColor.primary
    }
}

/// Surface + hairlineStrong border.
struct CLSecondaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CLTypography.button)
            .foregroundStyle(CLColor.ink)
            .frame(maxWidth: .infinity)
            .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
            .background(CLColor.surface)
            .overlay(
                RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous)
                    .stroke(CLColor.hairlineStrong, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(reduceMotion ? .easeOut(duration: 0.15) : nil, value: configuration.isPressed)
    }
}

// MARK: - View helpers

extension View {
    /// Warm canvas behind a screen.
    func clCanvasBackground() -> some View {
        background(CLColor.canvas.ignoresSafeArea())
    }

    /// Soft input chrome: surface, hairline, radiusMd.
    func clTextFieldChrome() -> some View {
        padding(CLSpacing.sm)
            .background(CLColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous)
                    .stroke(CLColor.hairline, lineWidth: 1)
            )
    }

    /// Soft card plate on canvas.
    func clCardStyle(padded: Bool = true) -> some View {
        padding(padded ? CLSpacing.md : 0)
            .background(CLColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: CLRadius.lg, style: .continuous))
            .shadow(color: CLShadow.cardColor, radius: CLShadow.cardRadius, x: 0, y: CLShadow.cardY)
    }

    func clSoftSpring<V: Equatable>(value: V) -> some View {
        modifier(CLSoftSpringModifier(value: value))
    }

    /// Soft appear; Reduce Motion → fade only.
    func clAppear(delay: Double = 0) -> some View {
        modifier(CLAppearModifier(delay: delay))
    }
}

// MARK: - Soft spring (Reduce Motion → ease)

private struct CLSoftSpringModifier<V: Equatable>: ViewModifier {
    let value: V
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.animation(
            reduceMotion ? .easeOut(duration: 0.2) : CLMotion.micro,
            value: value
        )
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
            .onAppear {
                guard !appeared else { return }
                if reduceMotion {
                    withAnimation(.easeOut(duration: 0.2).delay(delay)) {
                        appeared = true
                    }
                } else {
                    withAnimation(CLMotion.softLarge.delay(delay)) {
                        appeared = true
                    }
                }
            }
    }
}
