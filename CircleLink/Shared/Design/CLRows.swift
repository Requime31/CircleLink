import SwiftUI

struct CLListRow<Leading: View, Trailing: View>: View {
    let title: String
    var subtitle: String? = nil
    private let leading: Leading
    private let trailing: Trailing

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center, spacing: CLSpacing.sm) {
            leading
            VStack(alignment: .leading, spacing: CLSpacing.xxs) {
                Text(title).font(CLTypography.body).foregroundStyle(CLColor.ink)
                if let subtitle {
                    Text(subtitle)
                        .font(CLTypography.footnote)
                        .foregroundStyle(CLColor.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            trailing
        }
        .padding(.vertical, CLSpacing.xs)
        .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
        .contentShape(Rectangle())
    }
}

extension CLListRow where Leading == EmptyView, Trailing == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle, leading: { EmptyView() }, trailing: { EmptyView() })
    }
}

struct CLSettingsSection<Content: View>: View {
    let title: String
    private let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CLSpacing.sm) {
            CLSectionHeader(title)
            CLCard(variant: .outlined, padding: 0) { content }
        }
    }
}

struct CLSettingsRow<Trailing: View>: View {
    let title: String
    var subtitle: String? = nil
    var systemImage: String? = nil
    var role: ButtonRole? = nil
    private let trailing: Trailing

    init(
        title: String,
        subtitle: String? = nil,
        systemImage: String? = nil,
        role: ButtonRole? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.role = role
        self.trailing = trailing()
    }

    var body: some View {
        CLListRow(title: title, subtitle: subtitle) {
            if let systemImage {
                Image(systemName: systemImage)
                    .foregroundStyle(role == .destructive ? CLColor.error : CLColor.primary)
                    .frame(width: AccessibilityHelpers.minimumTouchTarget)
                    .accessibilityHidden(true)
            }
        } trailing: {
            trailing
        }
        .padding(.horizontal, CLSpacing.md)
    }
}

extension CLSettingsRow where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil, systemImage: String? = nil, role: ButtonRole? = nil) {
        self.init(title: title, subtitle: subtitle, systemImage: systemImage, role: role) { EmptyView() }
    }
}

struct CLDisclosureIndicator: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(CLTypography.footnote)
            .foregroundStyle(CLColor.inkMuted)
            .accessibilityHidden(true)
    }
}

extension CLSettingsRow where Trailing == CLDisclosureIndicator {
    init(title: String, subtitle: String? = nil, systemImage: String? = nil) {
        self.init(title: title, subtitle: subtitle, systemImage: systemImage) {
            CLDisclosureIndicator()
        }
    }
}

struct CLPersonRow<Trailing: View>: View {
    let name: String
    var detail: String? = nil
    var avatarURL: URL? = nil
    var avatarBase64: String? = nil
    var avatarSize: CGFloat = 52
    private let trailing: Trailing

    init(
        name: String,
        detail: String? = nil,
        avatarURL: URL? = nil,
        avatarBase64: String? = nil,
        avatarSize: CGFloat = 52,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.name = name
        self.detail = detail
        self.avatarURL = avatarURL
        self.avatarBase64 = avatarBase64
        self.avatarSize = avatarSize
        self.trailing = trailing()
    }

    var body: some View {
        CLListRow(title: name, subtitle: detail) {
            AvatarImageView(localPreview: nil, avatarBase64: avatarBase64, avatarURL: avatarURL, size: avatarSize)
                .accessibilityHidden(true)
        } trailing: {
            trailing
        }
        .accessibilityElement(children: .combine)
    }
}

extension CLPersonRow where Trailing == EmptyView {
    init(name: String, detail: String? = nil, avatarURL: URL? = nil, avatarBase64: String? = nil, avatarSize: CGFloat = 52) {
        self.init(name: name, detail: detail, avatarURL: avatarURL, avatarBase64: avatarBase64, avatarSize: avatarSize) {
            EmptyView()
        }
    }
}

struct CLCommunityLabel: View {
    let name: String
    var detail: String? = nil
    var imageURL: URL? = nil
    var size: CGFloat = 52

    var body: some View {
        HStack(spacing: CLSpacing.sm) {
            AsyncImage(url: imageURL) { phase in
                if case let .success(image) = phase {
                    image.resizable().scaledToFill()
                } else {
                    CLPlaceholderMedia(systemImage: "person.3.fill", label: "Community image")
                }
            }
            .frame(width: size, height: size)
            .clAvatarClip()
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: CLSpacing.xxs) {
                Text(name).font(CLTypography.body).foregroundStyle(CLColor.ink)
                if let detail { Text(detail).font(CLTypography.footnote).foregroundStyle(CLColor.inkMuted) }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct CLBadge: View {
    enum Style: Equatable { case neutral, accent, success, warning, destructive }

    let text: String
    var style: Style = .neutral

    var body: some View {
        Text(text)
            .font(CLTypography.caption)
            .foregroundStyle(foreground)
            .padding(.horizontal, CLSpacing.xs)
            .padding(.vertical, CLSpacing.xxs)
            .background(background)
            .clipShape(Capsule())
    }

    private var foreground: Color {
        switch style {
        case .neutral: return CLColor.inkSecondary
        case .accent: return CLColor.primaryStrong
        case .success: return CLColor.success
        case .warning: return CLColor.ink
        case .destructive: return CLColor.error
        }
    }

    private var background: Color {
        switch style {
        case .neutral: return CLColor.surfaceSoft
        case .accent: return CLColor.accentSoft
        case .success: return CLColor.tintMint
        case .warning: return CLColor.tintCream
        case .destructive: return CLColor.errorSoft
        }
    }
}

struct CLUnreadBadge: View {
    let count: Int
    var maximum = 99

    var body: some View {
        if count > 0 {
            Text(count > maximum ? "\(maximum)+" : "\(count)")
                .font(CLTypography.caption)
                .foregroundStyle(CLColor.onPrimaryStrong)
                .padding(.horizontal, CLSpacing.xs)
                .frame(minWidth: CLSpacing.lg, minHeight: CLSpacing.lg)
                .background(CLColor.primary)
                .clipShape(Capsule())
                .accessibilityLabel("\(count) unread messages")
        }
    }
}
