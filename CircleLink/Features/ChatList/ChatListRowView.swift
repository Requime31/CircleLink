import SwiftUI

/// Shared chat row for the main list and Hidden chats.
struct ChatListRowView: View {
    /// Shared list insets so Hidden chats match the main list. Row padding is separate (`rowVerticalPadding`).
    static let listRowInsets = EdgeInsets(
        top: CLSpacing.xs,
        leading: CLSpacing.screenHorizontal,
        bottom: CLSpacing.xs,
        trailing: CLSpacing.screenHorizontal
    )

    /// Tuned against the list on device while preserving the approved airy spacing.
    static let rowVerticalPadding: CGFloat = CLSpacing.md - 2

    let chat: ChatSummary

    private let avatarSize: CGFloat = 56

    var body: some View {
        HStack(spacing: CLSpacing.md) {
            AvatarImageView(
                localPreview: nil,
                avatarBase64: chat.avatarBase64,
                avatarURL: chat.avatarURL,
                size: avatarSize
            )

            VStack(alignment: .leading, spacing: CLSpacing.xxs) {
                HStack(alignment: .firstTextBaseline) {
                    Text(chat.title)
                        .font(CLTypography.headline)
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
                        .font(CLTypography.subheadline)
                        .foregroundStyle(CLColor.inkSecondary)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    if chat.unreadCount > 0 {
                        Text(chat.unreadCount >= 100 ? "99+" : "\(chat.unreadCount)")
                            .font(CLTypography.caption)
                            .foregroundStyle(CLColor.onPrimaryStrong)
                            .lineLimit(1)
                            .padding(.horizontal, 6)
                            .frame(minWidth: 20, minHeight: 20)
                            .background(Capsule().fill(CLColor.primaryStrong))
                            .accessibilityHidden(true)
                    }
                }
            }
        }
        .padding(.vertical, Self.rowVerticalPadding)
        .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
        .contentShape(Rectangle())
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
