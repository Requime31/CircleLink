import SwiftUI

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
                        .foregroundStyle(CLColor.inkMuted)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .empty:
                    emptyState
                case let .error(message):
                    errorState(message: message)
                case let .loaded(chats):
                    chatsList(chats)
                }
            }
            .clCanvasBackground()
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
        List(chats) { chat in
            Button {
                onChatSelected(chat.id)
            } label: {
                ChatRowView(chat: chat)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel(for: chat))
            .listRowBackground(CLColor.canvas)
            .listRowSeparatorTint(CLColor.hairline)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(CLColor.canvas)
        .clAppear()
    }

    private var emptyState: some View {
        VStack(spacing: CLSpacing.sm) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundStyle(CLColor.inkMuted)
                .padding(CLSpacing.md)
                .background(Circle().fill(CLColor.primarySoft))
                .accessibilityHidden(true)
            Text("No chats yet")
                .font(CLTypography.title2)
                .foregroundStyle(CLColor.ink)
            Text("Accept a Connect request to start a conversation.")
                .font(CLTypography.subheadline)
                .foregroundStyle(CLColor.inkSecondary)
                .multilineTextAlignment(.center)
            Button("Refresh") {
                Task { await viewModel.loadChats() }
            }
            .buttonStyle(CLSecondaryButtonStyle())
            .padding(.top, CLSpacing.xs)
            .accessibilityLabel("Refresh chats list")
        }
        .padding(CLSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: CLSpacing.sm) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(CLColor.error)
                .padding(CLSpacing.md)
                .background(Circle().fill(CLColor.errorSoft))
                .accessibilityHidden(true)
            Text(message)
                .font(CLTypography.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(CLColor.inkSecondary)
                .accessibilityLabel("Error: \(message)")
            Button("Retry") {
                Task { await viewModel.loadChats() }
            }
            .buttonStyle(CLSecondaryButtonStyle())
            .padding(.top, CLSpacing.xs)
            .accessibilityLabel("Retry loading chats")
        }
        .padding(CLSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        if chat.unreadCount > 0 {
            parts.append("\(chat.unreadCount) unread")
        }
        return parts.joined(separator: ", ")
    }
}

private struct ChatRowView: View {
    let chat: ChatSummary

    var body: some View {
        HStack(spacing: CLSpacing.sm) {
            ZStack(alignment: .topTrailing) {
                AvatarImageView(
                    localPreview: nil,
                    avatarBase64: chat.avatarBase64,
                    avatarURL: chat.avatarURL,
                    size: 52
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
                        .font(CLTypography.headline)
                        .foregroundStyle(CLColor.ink)
                        .lineLimit(1)

                    Spacer(minLength: CLSpacing.xs)

                    if let lastMessageAt = chat.lastMessageAt {
                        Text(lastMessageAt.formatted(ChatListDateFormat.style))
                            .font(CLTypography.caption)
                            .foregroundStyle(CLColor.inkMuted)
                    }
                }

                Text(chat.lastMessageText ?? "No messages yet")
                    .font(CLTypography.subheadline)
                    .foregroundStyle(CLColor.inkSecondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, CLSpacing.xxs)
        .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var unreadIndicator: some View {
        if chat.unreadCount == 1 {
            Circle()
                .fill(CLColor.primary)
                .frame(width: 10, height: 10)
                .overlay(
                    Circle()
                        .stroke(CLColor.canvas, lineWidth: 2)
                )
        } else {
            Text(unreadBadgeText)
                .font(CLTypography.caption)
                .foregroundStyle(CLColor.onPrimary)
                .padding(.horizontal, CLSpacing.xs)
                .padding(.vertical, CLSpacing.xxs)
                .background(CLColor.primarySoft)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(CLColor.hairline, lineWidth: 1)
                )
        }
    }

    private var unreadBadgeText: String {
        chat.unreadCount > 99 ? "99+" : "\(chat.unreadCount)"
    }
}

private enum ChatListDateFormat {
    static let style = Date.FormatStyle(date: .abbreviated, time: .shortened)
        .locale(.current)
}
