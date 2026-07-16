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
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .empty:
                    emptyState
                case let .error(message):
                    errorState(message: message)
                case let .loaded(chats):
                    chatsList(chats)
                }
            }
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
        }
        .listStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("No chats yet")
                .font(.title3)
            Text("Accept a Connect request to start a conversation.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Refresh") {
                Task { await viewModel.loadChats() }
            }
            .accessibilityLabel("Refresh chats list")
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Error: \(message)")
            Button("Retry") {
                Task { await viewModel.loadChats() }
            }
            .accessibilityLabel("Retry loading chats")
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func accessibilityLabel(for chat: ChatSummary) -> String {
        var parts = [chat.title]
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
        HStack(spacing: 12) {
            ZStack(alignment: .topTrailing) {
                AvatarImageView(
                    localPreview: nil,
                    avatarBase64: chat.avatarBase64,
                    avatarURL: chat.avatarURL,
                    size: 52
                )

                if chat.unreadCount > 0 {
                    Text(unreadBadgeText)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color(red: 1.0, green: 0.22, blue: 0.36))
                        .clipShape(Capsule())
                        .offset(x: 6, y: -4)
                        .accessibilityHidden(true)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(chat.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(red: 0.133, green: 0.133, blue: 0.133))
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    if let lastMessageAt = chat.lastMessageAt {
                        Text(lastMessageAt.formatted(ChatListDateFormat.style))
                            .font(.system(size: 13))
                            .foregroundStyle(Color(red: 0.416, green: 0.416, blue: 0.416))
                    }
                }

                Text(chat.lastMessageText ?? "No messages yet")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(red: 0.416, green: 0.416, blue: 0.416))
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private var unreadBadgeText: String {
        chat.unreadCount > 99 ? "99+" : "\(chat.unreadCount)"
    }
}

private enum ChatListDateFormat {
    static let style = Date.FormatStyle(date: .abbreviated, time: .shortened)
        .locale(.current)
}
