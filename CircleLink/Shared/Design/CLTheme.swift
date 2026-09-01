import SwiftUI
import UIKit

/// CircleLink design tokens from local `DESIGN.md` (Sunset Parchment).
/// View chrome only — no Domain / networking.

// MARK: - Color

enum CLColor {
    // Surfaces
    static let canvas = dynamic(light: 0xFCF9F8, dark: 0x1C1716)
    static let surface = dynamic(light: 0xFFFFFF, dark: 0x251F1D)
    static let surfaceSoft = dynamic(light: 0xF6F3F2, dark: 0x302724)
    static let hairline = dynamic(
        light: 0xE8E4DF,
        dark: 0x4A3D38,
        lightHighContrast: 0x9B8178,
        darkHighContrast: 0x8F746A
    )
    static let hairlineStrong = dynamic(
        light: 0xDCC1B9,
        dark: 0x6A5148,
        lightHighContrast: 0x7C5D53,
        darkHighContrast: 0xB58C7D
    )

    // Ink
    static let ink = dynamic(light: 0x1C1B1B, dark: 0xFFF8F5)
    static let inkSecondary = dynamic(light: 0x55423D, dark: 0xE4D4CE)
    static let inkMuted = dynamic(
        light: 0x88726C,
        dark: 0xBBA39A,
        lightHighContrast: 0x6B554E,
        darkHighContrast: 0xD0B8AF
    )
    static let inkDisabled = dynamic(light: 0xB8B2A8, dark: 0x806F69)

    // Primary (Sunset Clay)
    static let primary = dynamic(
        light: 0xE67E5F,
        dark: 0xFF9D7D,
        lightHighContrast: 0x9B442A,
        darkHighContrast: 0xFFAD91
    )
    static let primaryPressed = dynamic(light: 0x9B442A, dark: 0xE67E5F)
    /// Quieter soft CTA fill (DESIGN.md default). Prefer over `primarySoft` for buttons.
    static let accentSoft = dynamic(light: 0xF8E6E0, dark: 0x4B2E28)
    /// Selected chips / stronger soft highlight (`primary-fixed`).
    static let primarySoft = dynamic(light: 0xFFDBD1, dark: 0x5B342B)
    static let primaryStrong = dynamic(light: 0x9B442A, dark: 0xFFAD91)
    /// Label on soft fills (`accentSoft` / `primarySoft`).
    static let onPrimary = dynamic(light: 0x1C1B1B, dark: 0xFFF8F5)
    static let onPrimaryStrong = dynamic(light: 0xFFFFFF, dark: 0x27130E)

    // Soft tints — light use only
    static let tintPeach = dynamic(light: 0xFFDBD1, dark: 0x5B342B)
    static let tintCream = dynamic(light: 0xF6F3F2, dark: 0x302724)
    static let tintMint = dynamic(light: 0xE4F3EC, dark: 0x213A30)
    static let tintRose = dynamic(light: 0xFFDAD6, dark: 0x4D2927)

    // Semantic
    static let error = dynamic(light: 0xBA1A1A, dark: 0xFFB4AB)
    static let errorSoft = dynamic(light: 0xFFDAD6, dark: 0x4D2927)
    static let success = dynamic(light: 0x3D9B6E, dark: 0x75D6A6)
    static let warning = dynamic(light: 0xD4A017, dark: 0xF4C95D)

    private static func dynamic(
        light: UInt32,
        dark: UInt32,
        lightHighContrast: UInt32? = nil,
        darkHighContrast: UInt32? = nil
    ) -> Color {
        Color(UIColor { traits in
            let isDark = traits.userInterfaceStyle == .dark
            let standard = isDark ? dark : light
            let highContrast = isDark ? darkHighContrast : lightHighContrast
            let hex = traits.accessibilityContrast == .high ? highContrast ?? standard : standard
            return UIColor(hex: hex)
        })
    }
}

/// UIKit bridge for the shared semantic palette. Keep UIKit features free of raw RGB values.
enum CLUIColor {
    static let canvas = UIColor(CLColor.canvas)
    static let surface = UIColor(CLColor.surface)
    static let surfaceSoft = UIColor(CLColor.surfaceSoft)
    static let hairline = UIColor(CLColor.hairline)
    static let hairlineStrong = UIColor(CLColor.hairlineStrong)
    static let ink = UIColor(CLColor.ink)
    static let inkSecondary = UIColor(CLColor.inkSecondary)
    static let inkMuted = UIColor(CLColor.inkMuted)
    static let inkDisabled = UIColor(CLColor.inkDisabled)
    static let primary = UIColor(CLColor.primary)
    static let primaryPressed = UIColor(CLColor.primaryPressed)
    static let primarySoft = UIColor(CLColor.primarySoft)
    static let onPrimaryStrong = UIColor(CLColor.onPrimaryStrong)
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
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
    /// Default mobile side margin — use on every screen (DESIGN.md §0).
    static let screenHorizontal: CGFloat = 20
}

enum CLRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 14
    static let lg: CGFloat = 18
    static let xl: CGFloat = 24
}

enum CLShadow {
    /// Level-2 floating only (FAB / compose). Rare. ~4% of ink.
    static let floatingColor = CLColor.ink.opacity(0.04)
    static let floatingRadius: CGFloat = 20
    static let floatingY: CGFloat = 4

    /// Elevated shadow — rare (Connect Discover hero deck only). Prefer hairline cards.
    static let elevatedColor = CLColor.ink.opacity(0.08)
    static let elevatedRadius: CGFloat = 24
    static let elevatedY: CGFloat = 8

    /// Alias for call sites that still reference card shadow (Connect deck).
    static let cardColor = elevatedColor
    static let cardRadius: CGFloat = elevatedRadius
    static let cardY: CGFloat = elevatedY
}

enum CLAvatar {
    /// Shared avatar corner radius (DESIGN.md §0).
    static let cornerRadius: CGFloat = CLRadius.md

    /// Avatar shape used throughout the app, including Chats.
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

/// Default CTA: quieter `accentSoft` + ink (DESIGN.md). Prefer over solid clay.
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
        return pressed ? CLColor.accentSoft.opacity(0.85) : CLColor.accentSoft
    }
}

/// Solid Sunset Clay — rare high-emphasis only (FAB, Say Hi). Not the default CTA.
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
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CLTypography.button)
            .foregroundStyle(isEnabled ? CLColor.ink : CLColor.inkDisabled)
            .frame(maxWidth: .infinity)
            .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
            .background(background(configuration.isPressed))
            .overlay(
                RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous)
                    .stroke(isEnabled ? CLColor.hairlineStrong : CLColor.hairline, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous))
            .animation(reduceMotion ? .easeOut(duration: 0.15) : nil, value: configuration.isPressed)
    }

    private func background(_ pressed: Bool) -> Color {
        guard isEnabled else { return CLColor.surfaceSoft }
        return pressed ? CLColor.surfaceSoft : CLColor.surface
    }
}

// MARK: - Chip

/// Capsule filter / interest / tag.
/// - Interactive selection: `isSelected` → `accentSoft` + `primary` text + `.isSelected`
/// - Display accent (tags): `isEmphasized` → same colors, no selected trait
struct CLChip: View {
    let title: String
    var isSelected: Bool = false
    /// Visual accent without VoiceOver “selected” (read-only tags).
    var isEmphasized: Bool = false
    var isDisabled: Bool = false
    var accessibilityLabelText: String? = nil
    var accessibilityHintText: String? = nil
    var action: (() -> Void)? = nil

    private var showsAccent: Bool { isSelected || isEmphasized }
    private var isInteractive: Bool { action != nil }

    var body: some View {
        Group {
            if let action {
                Button(action: action) { label }
                    .buttonStyle(.plain)
            } else {
                label
            }
        }
        .disabled(isDisabled)
        .opacity(isDisabled && !showsAccent ? 0.45 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabelText ?? title)
        .accessibilityAddTraits(combinedTraits)
        .modifier(CLOptionalAccessibilityHint(hint: accessibilityHintText))
        .accessibilityRespondsToUserInteraction(isInteractive && !isDisabled)
    }

    private var combinedTraits: AccessibilityTraits {
        switch (isInteractive, isSelected) {
        case (true, true):
            return [.isButton, .isSelected]
        case (true, false):
            return .isButton
        case (false, true):
            return .isSelected
        case (false, false):
            return []
        }
    }

    private var label: some View {
        Text(title)
            .font(CLTypography.footnote)
            .foregroundStyle(showsAccent ? CLColor.primary : CLColor.inkSecondary)
            .padding(.horizontal, CLSpacing.sm)
            .padding(.vertical, CLSpacing.xs)
            .frame(
                minWidth: isInteractive ? AccessibilityHelpers.minimumTouchTarget : nil,
                minHeight: isInteractive ? AccessibilityHelpers.minimumTouchTarget : nil
            )
            .background(showsAccent ? CLColor.accentSoft : CLColor.surfaceSoft)
            .clipShape(Capsule())
            .clSoftSpring(value: showsAccent)
    }
}

/// Applies VoiceOver hint only when non-nil / non-empty.
private struct CLOptionalAccessibilityHint: ViewModifier {
    let hint: String?

    func body(content: Content) -> some View {
        if let hint, !hint.isEmpty {
            content.accessibilityHint(hint)
        } else {
            content
        }
    }
}

// MARK: - View helpers

extension View {
    /// Parchment canvas behind a screen.
    func clCanvasBackground() -> some View {
        background(CLColor.canvas.ignoresSafeArea())
    }

    /// Soft input chrome: surface, hairline → `primary` when focused, radiusMd.
    func clTextFieldChrome(isFocused: Bool = false) -> some View {
        padding(CLSpacing.sm)
            .background(CLColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous)
                    .stroke(isFocused ? CLColor.primary : CLColor.hairline, lineWidth: 1)
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

    /// Rare elevated hero (Connect Discover deck). Prefer `clCardStyle` (hairline) elsewhere.
    func clElevatedCardStyle(padded: Bool = true) -> some View {
        padding(padded ? CLSpacing.md : 0)
            .background(CLColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: CLRadius.xl, style: .continuous))
            .shadow(color: CLShadow.elevatedColor, radius: CLShadow.elevatedRadius, x: 0, y: CLShadow.elevatedY)
    }

    /// Level-2 floating shadow — rare (FAB / compose only).
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

    /// Shared avatar clip — squircle everywhere, including Chats.
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
