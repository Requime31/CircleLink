import SwiftUI

struct CLFormSection<Content: View>: View {
    let title: String
    var hint: String? = nil
    private let content: Content

    init(_ title: String, hint: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.hint = hint
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CLSpacing.sm) {
            CLSectionHeader(title, subtitle: hint)
            content
        }
    }
}

struct CLFieldCard<Content: View>: View {
    var state: CLFieldState = .normal
    private let content: Content

    init(state: CLFieldState = .normal, @ViewBuilder content: () -> Content) {
        self.state = state
        self.content = content()
    }

    var body: some View {
        content
            .padding(CLSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CLColor.surface)
            .clipShape(shape)
            .overlay(shape.stroke(state.borderColor, lineWidth: 1))
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous)
    }
}

enum CLFieldState: Equatable {
    case normal
    case focused
    case invalid
    case disabled

    var borderColor: Color {
        switch self {
        case .normal: return CLColor.hairline
        case .focused: return CLColor.primary
        case .invalid: return CLColor.error
        case .disabled: return CLColor.hairline
        }
    }
}

struct CLFormLabel: View {
    let title: String
    var isRequired = false

    var body: some View {
        Text(isRequired ? "\(title) (required)" : title)
            .font(CLTypography.footnote)
            .foregroundStyle(CLColor.inkSecondary)
            .accessibilityAddTraits(.isHeader)
    }
}

struct CLFormHint: View {
    let message: String

    var body: some View {
        Text(message)
            .font(CLTypography.footnote)
            .foregroundStyle(CLColor.inkMuted)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct CLValidationMessage: View {
    enum Style: Equatable { case error, warning, success }

    let message: String
    var style: Style = .error

    var body: some View {
        Label(message, systemImage: icon)
            .font(CLTypography.footnote)
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel("\(prefix): \(message)")
    }

    private var icon: String {
        switch style {
        case .error: return "exclamationmark.circle"
        case .warning: return "exclamationmark.triangle"
        case .success: return "checkmark.circle"
        }
    }

    private var prefix: String {
        switch style {
        case .error: return "Error"
        case .warning: return "Warning"
        case .success: return "Success"
        }
    }

    private var color: Color {
        switch style {
        case .error: return CLColor.error
        case .warning: return CLColor.warning
        case .success: return CLColor.success
        }
    }
}

struct CLCharacterCounterConfiguration: Equatable {
    let count: Int
    let limit: Int
    var label: String = "Text"

    var isOverLimit: Bool { count > limit }
    var remaining: Int { limit - count }
    var accessibilityValue: String { "\(label), \(count) of \(limit) characters" }
}

struct CLCharacterCounter: View {
    let configuration: CLCharacterCounterConfiguration

    init(count: Int, limit: Int, label: String = "Text") {
        configuration = .init(count: count, limit: limit, label: label)
    }

    var body: some View {
        Text("\(configuration.count)/\(configuration.limit)")
            .font(CLTypography.caption)
            .foregroundStyle(configuration.isOverLimit ? CLColor.error : CLColor.inkMuted)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .accessibilityLabel(configuration.accessibilityValue)
    }
}

struct CLTextFieldConfiguration: Equatable {
    var title: String
    var prompt: String
    var hint: String? = nil
    var isRequired = false
    var axis: Axis = .horizontal
    var lineLimit: ClosedRange<Int>? = nil
}

struct CLTextField: View {
    let configuration: CLTextFieldConfiguration
    @Binding var text: String
    var state: CLFieldState = .normal

    var body: some View {
        VStack(alignment: .leading, spacing: CLSpacing.xs) {
            CLFormLabel(title: configuration.title, isRequired: configuration.isRequired)
            CLFieldCard(state: state) {
                configuredField
            }
            if let hint = configuration.hint { CLFormHint(message: hint) }
        }
    }

    @ViewBuilder private var configuredField: some View {
        if let lineLimit = configuration.lineLimit {
            baseField.lineLimit(lineLimit)
        } else {
            baseField
        }
    }

    private var baseField: some View {
        TextField(configuration.prompt, text: $text, axis: configuration.axis)
            .font(CLTypography.body)
            .foregroundStyle(CLColor.ink)
            .disabled(state == .disabled)
            .accessibilityLabel(configuration.title)
    }
}

struct CLSecureField: View {
    let title: String
    let prompt: String
    @Binding var text: String
    var hint: String? = nil
    var state: CLFieldState = .normal

    var body: some View {
        VStack(alignment: .leading, spacing: CLSpacing.xs) {
            CLFormLabel(title: title)
            CLFieldCard(state: state) {
                SecureField(prompt, text: $text)
                    .textContentType(.password)
                    .font(CLTypography.body)
                    .foregroundStyle(CLColor.ink)
                    .disabled(state == .disabled)
                    .accessibilityLabel(title)
            }
            if let hint { CLFormHint(message: hint) }
        }
    }
}

struct CLSearchField: View {
    let prompt: String
    @Binding var text: String
    var accessibilityLabel = "Search"
    var focus: FocusState<Bool>.Binding? = nil
    var onClear: (() -> Void)? = nil
    var onSubmit: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: CLSpacing.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(CLColor.inkMuted)
                .accessibilityHidden(true)
            searchTextField
            if text.isEmpty == false {
                Button {
                    text = ""
                    onClear?()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .frame(
                            width: AccessibilityHelpers.minimumTouchTarget,
                            height: AccessibilityHelpers.minimumTouchTarget
                        )
                }
                .buttonStyle(.plain)
                .foregroundStyle(CLColor.inkMuted)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.leading, CLSpacing.sm)
        .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
        .background(CLColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous).stroke(CLColor.hairline))
    }

    @ViewBuilder private var searchTextField: some View {
        if let focus {
            baseTextField.focused(focus)
        } else {
            baseTextField
        }
    }

    private var baseTextField: some View {
        TextField(prompt, text: $text)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .onSubmit { onSubmit?() }
            .accessibilityLabel(accessibilityLabel)
    }
}

struct CLTextEditor: View {
    let title: String
    @Binding var text: String
    var hint: String? = nil
    var minimumHeight: CGFloat = 120
    var state: CLFieldState = .normal

    var body: some View {
        VStack(alignment: .leading, spacing: CLSpacing.xs) {
            CLFormLabel(title: title)
            CLFieldCard(state: state) {
                TextEditor(text: $text)
                    .scrollContentBackground(.hidden)
                    .font(CLTypography.body)
                    .foregroundStyle(CLColor.ink)
                    .frame(minHeight: minimumHeight)
                    .disabled(state == .disabled)
                    .accessibilityLabel(title)
            }
            if let hint { CLFormHint(message: hint) }
        }
    }
}

struct CLAsyncButtonConfiguration: Equatable {
    enum Style: Equatable { case primary, emphasis, secondary, destructive }

    let title: String
    var loadingTitle: String? = nil
    var accessibilityLabel: String? = nil
    var accessibilityHint: String? = nil
    var style: Style = .primary
    var fillsWidth = true

    func displayedTitle(isRunning: Bool) -> String {
        isRunning ? loadingTitle ?? title : title
    }

    func isInteractionDisabled(isRunning: Bool, isDisabled: Bool) -> Bool {
        isRunning || isDisabled
    }
}

struct CLAsyncButton: View {
    let configuration: CLAsyncButtonConfiguration
    var isDisabled = false
    var onError: ((Error) -> Void)? = nil
    let action: () async throws -> Void

    @State private var isRunning = false

    var body: some View {
        Button {
            guard isRunning == false else { return }
            isRunning = true
            Task {
                do { try await action() } catch { onError?(error) }
                isRunning = false
            }
        } label: {
            HStack(spacing: CLSpacing.xs) {
                if isRunning { ProgressView().tint(foreground) }
                Text(configuration.displayedTitle(isRunning: isRunning))
            }
            .frame(maxWidth: configuration.fillsWidth ? .infinity : nil)
        }
        .buttonStyle(AnyCLButtonStyle(style: configuration.style, fillsWidth: configuration.fillsWidth))
        .disabled(configuration.isInteractionDisabled(isRunning: isRunning, isDisabled: isDisabled))
        .accessibilityLabel(configuration.accessibilityLabel ?? configuration.title)
        .accessibilityValue(isRunning ? "In progress" : "")
        .modifier(CLAccessibilityHint(hint: configuration.accessibilityHint))
    }

    private var foreground: Color {
        configuration.style == .destructive ? CLColor.onPrimaryStrong : CLColor.ink
    }

}

struct AnyCLButtonStyle: ButtonStyle {
    let style: CLAsyncButtonConfiguration.Style
    var fillsWidth = true

    func makeBody(configuration: Configuration) -> some View {
        CLAnyButtonStyleBody(
            label: configuration.label,
            style: style,
            fillsWidth: fillsWidth,
            isPressed: configuration.isPressed
        )
    }
}

private struct CLAnyButtonStyleBody<Label: View>: View {
    let label: Label
    let style: CLAsyncButtonConfiguration.Style
    let fillsWidth: Bool
    let isPressed: Bool

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ViewBuilder var body: some View {
        switch style {
        case .primary:
            label
                .font(CLTypography.button)
                .foregroundStyle(isEnabled ? CLColor.onPrimary : CLColor.inkDisabled)
                .padding(.horizontal, fillsWidth ? 0 : CLSpacing.md)
                .frame(maxWidth: fillsWidth ? .infinity : nil)
                .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
                .background(primaryBackground)
                .clipShape(buttonShape)
                .opacity(isPressed && isEnabled ? 0.92 : 1)
                .animation(pressAnimation, value: isPressed)

        case .emphasis:
            label
                .font(CLTypography.button)
                .foregroundStyle(isEnabled ? CLColor.onPrimaryStrong : CLColor.inkDisabled)
                .padding(.horizontal, fillsWidth ? 0 : CLSpacing.md)
                .frame(maxWidth: fillsWidth ? .infinity : nil)
                .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
                .background(emphasisBackground)
                .clipShape(buttonShape)
                .opacity(isPressed && isEnabled ? 0.92 : 1)
                .animation(pressAnimation, value: isPressed)

        case .secondary:
            label
                .font(CLTypography.button)
                .foregroundStyle(isEnabled ? CLColor.ink : CLColor.inkDisabled)
                .padding(.horizontal, fillsWidth ? 0 : CLSpacing.md)
                .frame(maxWidth: fillsWidth ? .infinity : nil)
                .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
                .background(secondaryBackground)
                .overlay(buttonShape.stroke(isEnabled ? CLColor.hairlineStrong : CLColor.hairline, lineWidth: 1))
                .clipShape(buttonShape)
                .animation(reduceMotion ? .easeOut(duration: 0.15) : nil, value: isPressed)

        case .destructive:
            label
                .font(CLTypography.button)
                .foregroundStyle(isEnabled ? CLColor.onPrimaryStrong : CLColor.inkDisabled)
                .padding(.horizontal, fillsWidth ? 0 : CLSpacing.md)
                .frame(maxWidth: fillsWidth ? .infinity : nil)
                .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
                .background(isEnabled ? CLColor.error.opacity(isPressed ? 0.82 : 1) : CLColor.surfaceSoft)
                .clipShape(buttonShape)
                .animation(pressAnimation, value: isPressed)
        }
    }

    private var buttonShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous)
    }

    private var primaryBackground: Color {
        guard isEnabled else { return CLColor.surfaceSoft }
        return isPressed ? CLColor.accentSoft.opacity(0.85) : CLColor.accentSoft
    }

    private var emphasisBackground: Color {
        guard isEnabled else { return CLColor.surfaceSoft }
        return isPressed ? CLColor.primaryPressed : CLColor.primary
    }

    private var secondaryBackground: Color {
        guard isEnabled else { return CLColor.surfaceSoft }
        return isPressed ? CLColor.surfaceSoft : CLColor.surface
    }

    private var pressAnimation: Animation? {
        reduceMotion ? .easeOut(duration: 0.15) : CLMotion.micro
    }
}
struct CLDestructiveButtonStyle: ButtonStyle {
    var fillsWidth = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CLTypography.button)
            .foregroundStyle(CLColor.onPrimaryStrong)
            .padding(.horizontal, fillsWidth ? 0 : CLSpacing.md)
            .frame(maxWidth: fillsWidth ? .infinity : nil)
            .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
            .background(CLColor.error.opacity(configuration.isPressed ? 0.82 : 1))
            .clipShape(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous))
    }
}
