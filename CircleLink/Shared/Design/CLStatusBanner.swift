import SwiftUI

/// Shared status / feedback strip for Connect and similar screens.
/// Same chrome for error and info — only colors differ.
struct CLStatusBanner: View {
    enum Style {
        case error
        case info
    }

    enum Presentation: Equatable {
        case banner
        case compact
        case inline
    }

    let message: String
    var style: Style = .info
    var presentation: Presentation = .banner
    var accessibilityPrefix: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: CLSpacing.xs) {
            if presentation != .inline {
                Image(systemName: style == .error ? "exclamationmark.circle" : "info.circle")
                    .accessibilityHidden(true)
            }
            Text(message)
        }
            .font(CLTypography.footnote)
            .foregroundStyle(foreground)
            .padding(presentation == .inline ? 0 : presentation == .compact ? CLSpacing.xs : CLSpacing.sm)
            .frame(maxWidth: presentation == .compact ? nil : .infinity, alignment: .leading)
            .background(presentation == .inline ? Color.clear : background)
            .clipShape(RoundedRectangle(cornerRadius: presentation == .compact ? CLRadius.sm : CLRadius.md, style: .continuous))
            .accessibilityLabel(accessibilityLabel)
    }

    private var foreground: Color {
        switch style {
        case .error: return CLColor.error
        case .info: return CLColor.inkSecondary
        }
    }

    private var background: Color {
        switch style {
        case .error: return CLColor.errorSoft
        case .info: return CLColor.surfaceSoft
        }
    }

    private var accessibilityLabel: String {
        if let accessibilityPrefix {
            return "\(accessibilityPrefix): \(message)"
        }
        return message
    }
}
