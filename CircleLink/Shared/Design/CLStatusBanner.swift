import SwiftUI

/// Shared status / feedback strip for Connect and similar screens.
/// Same chrome for error and info — only colors differ.
struct CLStatusBanner: View {
    enum Style {
        case error
        case info
    }

    let message: String
    var style: Style = .info
    var accessibilityPrefix: String? = nil

    var body: some View {
        Text(message)
            .font(CLTypography.footnote)
            .foregroundStyle(foreground)
            .padding(CLSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous))
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
