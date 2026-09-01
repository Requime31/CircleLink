import SwiftUI

struct CommunityPostCard: View {
    let post: CommunityPost
    let author: User?
    let canManage: Bool
    let currentUserId: String?
    let onSelectAuthor: (String) -> Void
    let onSelectMedia: (URL) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var trimmedText: String? {
        guard let text = post.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else { return nil }
        return text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CLSpacing.sm) {
            HStack(alignment: .center, spacing: CLSpacing.sm) {
                authorControl

                Spacer(minLength: CLSpacing.xs)
                if canManage {
                    Menu {
                        Button("Edit Post", action: onEdit)
                        Button("Delete Post", role: .destructive, action: onDelete)
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(CLColor.inkSecondary)
                            .frame(minWidth: AccessibilityHelpers.minimumTouchTarget,
                                   minHeight: AccessibilityHelpers.minimumTouchTarget)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Post actions")
                }
            }
            if let trimmedText {
                Text(trimmedText)
                    .font(CLTypography.body)
                    .foregroundStyle(CLColor.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(8)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let url = post.imageURL {
                Button {
                    onSelectMedia(url)
                } label: {
                    CommunityPostImage(url: url)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open post photo")
            }
        }
        .padding(CLSpacing.md)
        .background(CLColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: CLRadius.lg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: CLRadius.lg, style: .continuous).stroke(CLColor.hairline, lineWidth: 1))
    }

    private var authorPresentation: PostAuthorPresentation {
        PostAuthorPresentation(author: author, currentUserId: currentUserId)
    }

    @ViewBuilder
    private var authorControl: some View {
        if authorPresentation.selectableUserId != nil {
            Button { authorPresentation.selectAuthor(perform: onSelectAuthor) } label: { authorLabel }
                .buttonStyle(.plain)
                .accessibilityLabel("View profile for \(authorPresentation.displayName)")
        } else {
            authorLabel
                .accessibilityElement(children: .combine)
                .accessibilityLabel(authorAccessibilityLabel)
        }
    }

    private var authorLabel: some View {
        HStack(alignment: .center, spacing: CLSpacing.sm) {
            AvatarImageView(
                localPreview: nil,
                avatarBase64: author?.isSociallyAvailable == true ? author?.avatarBase64 : nil,
                avatarURL: author?.isSociallyAvailable == true ? author?.avatarURL : nil,
                size: 36
            )
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(authorPresentation.displayName)
                    .font(CLTypography.subheadline.weight(.semibold))
                    .foregroundStyle(CLColor.ink)
                    .lineLimit(1)

                Text(post.createdAt, format: .relative(presentation: .named))
                    .font(CLTypography.caption)
                    .foregroundStyle(CLColor.inkMuted)
                    .lineLimit(1)
            }
        }
        .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
        .contentShape(Rectangle())
    }

    private var authorAccessibilityLabel: String {
        "\(authorPresentation.displayName), \(post.createdAt.formatted(.relative(presentation: .named)))"
    }

}

struct CommunityPostImage: View {
    let url: URL
    var body: some View {
        Color.clear
            .aspectRatio(4 / 3, contentMode: .fit)
            .overlay {
                AsyncImage(url: url) { phase in
                    if case let .success(image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        CLColor.surfaceSoft.overlay { ProgressView().tint(CLColor.primary) }
                    }
                }
            }
        .clipShape(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous))
        .accessibilityHidden(true)
    }
}
