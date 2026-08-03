import SwiftUI

/// Context-menu peek: last messages only (no scroll). Phase 5 variant A.
struct ConversationPeekPreview: View {
    let chatTitle: String
    let isGroup: Bool
    let preview: ChatsViewModel.ConversationPreview?
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: CLSpacing.sm) {
            HStack {
                Text(chatTitle)
                    .font(CLTypography.headline)
                    .foregroundStyle(CLColor.ink)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text(isGroup ? "Group" : "Chat")
                    .font(CLTypography.caption)
                    .foregroundStyle(CLColor.inkMuted)
            }

            Divider()
                .background(CLColor.hairline)

            if isLoading && preview == nil {
                ProgressView()
                    .tint(CLColor.primary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                previewContent
            }
        }
        .padding(CLSpacing.md)
        .frame(width: 280)
        .background(CLColor.canvas)
    }

    @ViewBuilder
    private var previewContent: some View {
        switch preview {
        case let .loaded(messages)?:
            if messages.isEmpty {
                Text("No messages yet")
                    .font(CLTypography.subheadline)
                    .foregroundStyle(CLColor.inkSecondary)
                    .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
            } else {
                // Fixed stack — no ScrollView (gesture conflicts with context menu).
                VStack(alignment: .leading, spacing: CLSpacing.xs) {
                    ForEach(messages) { message in
                        peekBubble(for: message)
                    }
                }
            }
        case let .failed(message)?:
            VStack(spacing: CLSpacing.xs) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(CLColor.error)
                    .accessibilityHidden(true)
                Text("Couldn’t load preview")
                    .font(CLTypography.subheadline.weight(.semibold))
                    .foregroundStyle(CLColor.ink)
                Text(message)
                    .font(CLTypography.caption)
                    .foregroundStyle(CLColor.inkSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Preview error: \(message)")
        case nil:
            Text("No messages yet")
                .font(CLTypography.subheadline)
                .foregroundStyle(CLColor.inkSecondary)
                .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
        }
    }

    @ViewBuilder
    private func peekBubble(for message: ChatMessageItem) -> some View {
        let text = peekText(for: message)
        HStack {
            if message.isOutgoing { Spacer(minLength: 24) }
            Text(text)
                .font(CLTypography.subheadline)
                .foregroundStyle(CLColor.ink)
                .padding(.horizontal, CLSpacing.sm)
                .padding(.vertical, CLSpacing.xs)
                .background(message.isOutgoing ? CLColor.primarySoft : CLColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous))
            if !message.isOutgoing { Spacer(minLength: 24) }
        }
    }

    private func peekText(for message: ChatMessageItem) -> String {
        if let text = message.text, !text.isEmpty {
            return text
        }
        if message.imageURL != nil || message.localImageData != nil {
            return "Photo"
        }
        return " "
    }
}
