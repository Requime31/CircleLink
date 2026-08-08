import SwiftUI

/// Shared chat row for the main list and Hidden chats.
struct ChatListRowView: View {
    let chat: ChatSummary

    private let avatarSize: CGFloat = 56

    var body: some View {
        HStack(spacing: CLSpacing.md) {
            ZStack(alignment: .topTrailing) {
                AvatarImageView(
                    localPreview: nil,
                    avatarBase64: chat.avatarBase64,
                    avatarURL: chat.avatarURL,
                    size: avatarSize
                )

                if chat.unreadCount > 0 {
                    unreadIndicator
                        .offset(x: 4, y: -2)
                        .accessibilityHidden(true)
                }
            }

            VStack(alignment: .leading, spacing: CLSpacing.xxs) {
                HStack(alignment: .firstTextBaseline) {
                    Text(chat.title)
                        .font(CLTypography.footnote.weight(.semibold))
                        .foregroundStyle(CLColor.ink)
                        .lineLimit(1)

                    if chat.isMuted {
                        Image(systemName: "bell.slash.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(CLColor.inkMuted)
                            .accessibilityLabel("Muted")
                    }

                    Spacer(minLength: CLSpacing.xs)

                    if let lastMessageAt = chat.lastMessageAt {
                        Text(lastMessageAt.formatted(ChatListDateFormat.style))
                            .font(CLTypography.caption)
                            .foregroundStyle(CLColor.inkMuted)
                    }
                }

                HStack(alignment: .center, spacing: CLSpacing.xs) {
                    Text(chat.lastMessageText ?? "No messages yet")
                        .font(CLTypography.callout)
                        .foregroundStyle(CLColor.inkSecondary)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    if chat.unreadCount > 0 {
                        Circle()
                            .fill(CLColor.primary)
                            .frame(width: 10, height: 10)
                            .accessibilityHidden(true)
                    }
                }
            }
        }
        .padding(.vertical, CLSpacing.xs)
        .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var unreadIndicator: some View {
        if chat.unreadCount > 1 {
            Text(unreadBadgeText)
                .font(CLTypography.caption)
                .foregroundStyle(CLColor.onPrimaryStrong)
                .padding(.horizontal, CLSpacing.xs)
                .padding(.vertical, CLSpacing.xxs)
                .background(CLColor.primary)
                .clipShape(Capsule())
        }
    }

    private var unreadBadgeText: String {
        chat.unreadCount > 99 ? "99+" : "\(chat.unreadCount)"
    }
}

enum ChatListDateFormat {
    static let style = Date.FormatStyle(date: .abbreviated, time: .shortened)
        .locale(.current)
}

enum ChatListAccessibility {
    static func label(for chat: ChatSummary) -> String {
        var parts: [String] = []
        if chat.type == .group {
            parts.append("Group chat")
        }
        parts.append(chat.title)
        if chat.isMuted {
            parts.append("Muted")
        }
        if let lastMessageText = chat.lastMessageText, !lastMessageText.isEmpty {
            parts.append(lastMessageText)
        }
        if chat.unreadCount > 0 {
            parts.append("\(chat.unreadCount) unread")
        }
        return parts.joined(separator: ", ")
    }
}
