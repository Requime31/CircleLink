import SwiftUI

struct CLScreenHeaderAction {
    let systemImage: String
    let accessibilityLabel: String
    var accessibilityHint: String? = nil
    let action: () -> Void
}

struct CLIconButton: View {
    let systemImage: String
    let accessibilityLabel: String
    var accessibilityHint: String? = nil
    var role: ButtonRole? = nil
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            Image(systemName: systemImage)
                .font(CLTypography.headline)
                .frame(
                    width: AccessibilityHelpers.minimumTouchTarget,
                    height: AccessibilityHelpers.minimumTouchTarget
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(role == .destructive ? CLColor.error : CLColor.ink)
        .accessibilityLabel(accessibilityLabel)
        .modifier(CLAccessibilityHint(hint: accessibilityHint))
    }
}

struct CLBackButton: View {
    var label = "Back"
    var hint: String? = nil
    let action: () -> Void

    var body: some View {
        CLIconButton(
            systemImage: "chevron.left",
            accessibilityLabel: label,
            accessibilityHint: hint,
            action: action
        )
    }
}

struct CLCloseButton: View {
    var label = "Close"
    var hint: String? = nil
    let action: () -> Void

    var body: some View {
        CLIconButton(
            systemImage: "xmark",
            accessibilityLabel: label,
            accessibilityHint: hint,
            action: action
        )
    }
}

struct CLScreenHeader: View {
    enum Leading {
        case back(label: String = "Back", hint: String? = nil, action: () -> Void)
        case close(label: String = "Close", hint: String? = nil, action: () -> Void)
        case custom(CLScreenHeaderAction)
    }

    let title: String
    var subtitle: String? = nil
    var leading: Leading? = nil
    var trailing: CLScreenHeaderAction? = nil
    var showsDivider = true

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 0) {
            ViewThatFits(in: .horizontal) {
                standardLayout
                compactLayout
            }
            .padding(.horizontal, CLSpacing.screenHorizontal)
            .padding(.vertical, CLSpacing.xs)
            .frame(minHeight: AccessibilityHelpers.minimumTouchTarget + CLSpacing.md)

            if showsDivider { CLHairline() }
        }
        .background(CLColor.canvas)
    }

    private var standardLayout: some View {
        HStack(alignment: .center, spacing: CLSpacing.sm) {
            actionSlot(leading)
            titleBlock
            trailingSlot
        }
    }

    private var compactLayout: some View {
        VStack(alignment: .leading, spacing: CLSpacing.xs) {
            HStack {
                actionSlot(leading)
                Spacer(minLength: CLSpacing.sm)
                trailingSlot
            }
            titleBlock
                .padding(.horizontal, dynamicTypeSize.isAccessibilitySize ? 0 : CLSpacing.xxs)
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: CLSpacing.xxs) {
            Text(title)
                .font(CLTypography.title)
                .foregroundStyle(CLColor.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle)
                    .font(CLTypography.callout)
                    .foregroundStyle(CLColor.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func actionSlot(_ leading: Leading?) -> some View {
        if let leading {
            switch leading {
            case let .back(label, hint, action):
                CLBackButton(label: label, hint: hint, action: action)
            case let .close(label, hint, action):
                CLCloseButton(label: label, hint: hint, action: action)
            case let .custom(action):
                iconButton(action)
            }
        }
    }

    @ViewBuilder
    private var trailingSlot: some View {
        if let trailing { iconButton(trailing) }
    }

    private func iconButton(_ action: CLScreenHeaderAction) -> some View {
        CLIconButton(
            systemImage: action.systemImage,
            accessibilityLabel: action.accessibilityLabel,
            accessibilityHint: action.accessibilityHint,
            action: action.action
        )
    }
}

struct CLAccessibilityHint: ViewModifier {
    let hint: String?

    func body(content: Content) -> some View {
        if let hint, hint.isEmpty == false {
            content.accessibilityHint(hint)
        } else {
            content
        }
    }
}

