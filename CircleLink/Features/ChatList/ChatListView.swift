import SwiftUI

/// Chat list in Soft Orbit language. ViewModel bindings unchanged.
///
/// Data flow:
/// Appear / Refresh → ChatsViewModel.loadChats → ChatRepository
///   → state → list / empty / error UI
/// Tap row → onChatSelected(chatId) → host opens chat (UIKit)
struct ChatListView: View {
    @ObservedObject var viewModel: ChatsViewModel
    let onChatSelected: (String) -> Void

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .idle, .loading:
                    ProgressView("Loading chats…")
                        .tint(CLColor.primary)
                        .foregroundStyle(CLColor.muted)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .empty:
                    emptyState
                case let .error(message):
                    errorState(message: message)
                case let .loaded(chats):
                    chatsList(chats)
                }
            }
            .background(CLColor.canvas.ignoresSafeArea())
            .navigationTitle("Chats")
            .task {
                await viewModel.loadChats()
            }
            .refreshable {
                await viewModel.loadChats()
            }
        }
    }

    @ViewBuilder
    private func chatsList(_ chats: [ChatSummary]) -> some View {
        ScrollView {
            LazyVStack(spacing: CLSpacing.base) {
                ForEach(chats) { chat in
                    Button {
                        onChatSelected(chat.id)
                    } label: {
                        ChatRowView(chat: chat)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(accessibilityLabel(for: chat))
                }
            }
            .padding(CLSpacing.base)
            .clAppear()
        }
    }

    private var emptyState: some View {
        CLEmptyState(
            systemImage: "bubble.left.and.bubble.right",
            title: "No orbits open yet",
            message: "Accept a Connect request to start a conversation.",
            actionTitle: "Refresh",
            actionAccessibilityLabel: "Refresh chats list"
        ) {
            Task { await viewModel.loadChats() }
        }
    }

    private func errorState(message: String) -> some View {
        CLEmptyState(
            systemImage: "exclamationmark.triangle.fill",
            title: "Couldn't load chats",
            message: message,
            actionTitle: "Retry",
            actionAccessibilityLabel: "Retry loading chats",
            titleAccessibilityLabel: "Error: Couldn't load chats"
        ) {
            Task { await viewModel.loadChats() }
        }
    }

    private func accessibilityLabel(for chat: ChatSummary) -> String {
        var parts: [String] = []
        if chat.type == .group {
            parts.append("Group chat")
        }
        parts.append(chat.title)
        if let lastMessageText = chat.lastMessageText, !lastMessageText.isEmpty {
            parts.append(lastMessageText)
        }
        if let lastMessageAt = chat.lastMessageAt {
            parts.append(lastMessageAt.formatted(ChatListDateFormat.style))
        }
        if chat.unreadCount > 0 {
            parts.append("\(chat.unreadCount) unread")
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Row

private struct ChatRowView: View {
    let chat: ChatSummary

    var body: some View {
        HStack(spacing: CLSpacing.md) {
            ZStack(alignment: .topTrailing) {
                AvatarImageView(
                    localPreview: nil,
                    avatarBase64: chat.avatarBase64,
                    avatarURL: chat.avatarURL,
                    size: 52
                )

                if chat.unreadCount > 0 {
                    Text(unreadBadgeText)
                        .font(CLTypography.caption.weight(.semibold))
                        .foregroundStyle(CLColor.onPrimary)
                        .padding(.horizontal, CLSpacing.xs + 1)
                        .padding(.vertical, CLSpacing.xxs)
                        .background(CLColor.primary)
                        .clipShape(Capsule(style: .continuous))
                        .offset(x: 6, y: -4)
                        .accessibilityHidden(true)
                }
            }

            VStack(alignment: .leading, spacing: CLSpacing.xs) {
                HStack(alignment: .firstTextBaseline) {
                    Text(chat.title)
                        .font(CLTypography.section)
                        .foregroundStyle(CLColor.ink)
                        .lineLimit(1)

                    Spacer(minLength: CLSpacing.sm)

                    if let lastMessageAt = chat.lastMessageAt {
                        Text(lastMessageAt.formatted(ChatListDateFormat.style))
                            .font(CLTypography.caption)
                            .foregroundStyle(CLColor.muted)
                    }
                }

                Text(chat.lastMessageText ?? "No messages yet")
                    .font(CLTypography.callout)
                    .foregroundStyle(CLColor.muted)
                    .lineLimit(1)
            }
        }
        .padding(CLSpacing.base)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
        .contentShape(Rectangle())
        .clCardStyle()
    }

    private var unreadBadgeText: String {
        chat.unreadCount > 99 ? "99+" : "\(chat.unreadCount)"
    }
}

private enum ChatListDateFormat {
    static let style = Date.FormatStyle(date: .abbreviated, time: .shortened)
        .locale(.current)
}
