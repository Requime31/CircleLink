import SwiftUI

/// CircleLink design tokens from local `DESIGN.md` (Sunset Parchment).
/// View chrome only — no Domain / networking.

// MARK: - Color

enum CLColor {
    // Surfaces
    static let canvas = Color(red: 0.988, green: 0.976, blue: 0.973)       // #FCF9F8
    static let surface = Color.white                                         // #FFFFFF
    static let surfaceSoft = Color(red: 0.965, green: 0.953, blue: 0.949)   // #F6F3F2
    static let hairline = Color(red: 0.910, green: 0.894, blue: 0.875)      // #E8E4DF
    static let hairlineStrong = Color(red: 0.863, green: 0.757, blue: 0.725) // #DCC1B9

    // Ink
    static let ink = Color(red: 0.110, green: 0.106, blue: 0.106)           // #1C1B1B
    static let inkSecondary = Color(red: 0.333, green: 0.259, blue: 0.239)  // #55423D
    static let inkMuted = Color(red: 0.533, green: 0.447, blue: 0.424)      // #88726C
    static let inkDisabled = Color(red: 0.722, green: 0.698, blue: 0.659)   // #B8B2A8

    // Primary (Sunset Clay)
    static let primary = Color(red: 0.902, green: 0.494, blue: 0.373)       // #E67E5F
    static let primaryPressed = Color(red: 0.608, green: 0.267, blue: 0.165) // #9B442A
    static let primarySoft = Color(red: 1.000, green: 0.859, blue: 0.820)   // #FFDBD1
    static let primaryStrong = Color(red: 0.608, green: 0.267, blue: 0.165) // #9B442A
    static let onPrimary = Color(red: 0.110, green: 0.106, blue: 0.106)     // #1C1B1B
    static let onPrimaryStrong = Color.white

    // Soft tints — light use only
    static let tintPeach = Color(red: 1.000, green: 0.859, blue: 0.820)     // #FFDBD1
    static let tintCream = Color(red: 0.965, green: 0.953, blue: 0.949)     // #F6F3F2
    static let tintMint = Color(red: 0.894, green: 0.953, blue: 0.925)      // #E4F3EC
    static let tintRose = Color(red: 1.000, green: 0.855, blue: 0.839)      // #FFDAD6

    // Semantic
    static let error = Color(red: 0.729, green: 0.102, blue: 0.102)         // #BA1A1A
    static let errorSoft = Color(red: 1.000, green: 0.855, blue: 0.839)     // #FFDAD6
    static let success = Color(red: 0.239, green: 0.608, blue: 0.431)       // #3D9B6E
    static let warning = Color(red: 0.831, green: 0.627, blue: 0.090)       // #D4A017
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
    /// Default mobile side margin from Sunset Parchment brief.
    static let screenHorizontal: CGFloat = 20
}

enum CLRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 14
    static let lg: CGFloat = 18
    static let xl: CGFloat = 24
}

enum CLShadow {
    /// Level-2 floating only (FAB / compose). ~4% of ink.
    static let floatingColor = CLColor.ink.opacity(0.04)
    static let floatingRadius: CGFloat = 20
    static let floatingY: CGFloat = 4

    /// Stronger elevation for hero cards (Connect deck). Still soft — not Material-heavy.
    static let elevatedColor = CLColor.ink.opacity(0.08)
    static let elevatedRadius: CGFloat = 24
    static let elevatedY: CGFloat = 8

    /// Alias for call sites that still reference card shadow (Connect deck).
    static let cardColor = elevatedColor
    static let cardRadius: CGFloat = elevatedRadius
    static let cardY: CGFloat = elevatedY
}

enum CLAvatar {
    /// Squircle corner radius for avatars (DESIGN.md).
    static let cornerRadius: CGFloat = CLRadius.md

    static func shape() -> RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }
}

// MARK: - Typography (SF Pro + Dynamic Type)

enum CLTypography {
    static let display = Font.system(size: 34, weight: .bold, design: .default)
    static let largeTitle = Font.system(.largeTitle, design: .default).weight(.bold)
    static let title = Font.title2.weight(.semibold)
    static let title2 = Font.title3.weight(.semibold)
    static let headline = Font.headline.weight(.semibold)
    static let body = Font.body
    static let callout = Font.callout
    static let subheadline = Font.subheadline
    static let footnote = Font.footnote.weight(.medium)
    static let caption = Font.caption.weight(.semibold)
    static let button = Font.body.weight(.medium)
}

// MARK: - Motion

enum CLMotion {
    static let soft = Animation.spring(response: 0.35, dampingFraction: 0.82)
    static let softLarge = Animation.spring(response: 0.45, dampingFraction: 0.86)
    static let micro = Animation.spring(response: 0.28, dampingFraction: 0.78)
}

// MARK: - Button styles

/// Low-impact primary: `primarySoft` + ink (default CTA).
/// - `fillsWidth: true` (default) — full-width CTAs
/// - `fillsWidth: false` — compact row CTAs
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
            .animation(reduceMotion ? .easeOut(duration: 0.15) : CLMotion.micro, value: configuration.isPressed)
    }

    private func background(_ pressed: Bool) -> Color {
        guard isEnabled else { return CLColor.surfaceSoft }
        return pressed ? CLColor.primarySoft.opacity(0.85) : CLColor.primarySoft
    }
}

/// Solid Sunset Clay — FAB / Say Hi / high-emphasis only.
struct CLEmphasisButtonStyle: ButtonStyle {
    var fillsWidth: Bool = true

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CLTypography.button)
            .foregroundStyle(isEnabled ? CLColor.onPrimaryStrong : CLColor.inkDisabled)
            .padding(.horizontal, fillsWidth ? 0 : CLSpacing.md)
            .frame(maxWidth: fillsWidth ? .infinity : nil)
            .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
            .background(background(configuration.isPressed))
            .clipShape(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous))
            .opacity(configuration.isPressed && isEnabled ? 0.92 : 1)
            .animation(reduceMotion ? .easeOut(duration: 0.15) : CLMotion.micro, value: configuration.isPressed)
    }

    private func background(_ pressed: Bool) -> Color {
        guard isEnabled else { return CLColor.surfaceSoft }
        return pressed ? CLColor.primaryPressed : CLColor.primary
    }
}

/// Surface + hairline border.
struct CLSecondaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CLTypography.button)
            .foregroundStyle(CLColor.ink)
            .frame(maxWidth: .infinity)
            .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
            .background(configuration.isPressed ? CLColor.surfaceSoft : CLColor.surface)
            .overlay(
                RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous)
                    .stroke(CLColor.hairlineStrong, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous))
            .animation(reduceMotion ? .easeOut(duration: 0.15) : nil, value: configuration.isPressed)
    }
}

// MARK: - Chip

struct CLChip: View {
    let title: String
    var isSelected: Bool = false
    var action: (() -> Void)? = nil

    var body: some View {
        Group {
            if let action {
                Button(action: action) { label }
                    .buttonStyle(.plain)
            } else {
                label
            }
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var label: some View {
        Text(title)
            .font(CLTypography.footnote)
            .foregroundStyle(isSelected ? CLColor.primary : CLColor.inkSecondary)
            .padding(.horizontal, CLSpacing.sm)
            .padding(.vertical, CLSpacing.xs)
            .background(isSelected ? CLColor.primarySoft : CLColor.surfaceSoft)
            .clipShape(Capsule())
            .clSoftSpring(value: isSelected)
    }
}

// MARK: - View helpers

extension View {
    /// Parchment canvas behind a screen.
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

    /// Hairline card plate on canvas (default — no shadow).
    func clCardStyle(padded: Bool = true) -> some View {
        padding(padded ? CLSpacing.md : 0)
            .background(CLColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: CLRadius.xl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CLRadius.xl, style: .continuous)
                    .stroke(CLColor.hairline, lineWidth: 1)
            )
    }

    /// Hero / deck card with soft elevated shadow (Connect).
    func clElevatedCardStyle(padded: Bool = true) -> some View {
        padding(padded ? CLSpacing.md : 0)
            .background(CLColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: CLRadius.xl, style: .continuous))
            .shadow(color: CLShadow.elevatedColor, radius: CLShadow.elevatedRadius, x: 0, y: CLShadow.elevatedY)
    }

    /// Level-2 floating shadow (FAB / compose only).
    func clFloatingShadow() -> some View {
        shadow(color: CLShadow.floatingColor, radius: CLShadow.floatingRadius, x: 0, y: CLShadow.floatingY)
    }

    func clSoftSpring<V: Equatable>(value: V) -> some View {
        modifier(CLSoftSpringModifier(value: value))
    }

    /// Soft appear; Reduce Motion → fade only.
    func clAppear(delay: Double = 0) -> some View {
        modifier(CLAppearModifier(delay: delay))
    }

    /// Squircle avatar clip (radiusMd continuous).
    func clAvatarClip() -> some View {
        clipShape(CLAvatar.shape())
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
