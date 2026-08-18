import SwiftUI

struct CommunityPostCard: View {
    let post: CommunityPost
    let author: User?
    let canManage: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: CLSpacing.sm) {
            HStack(alignment: .center, spacing: CLSpacing.sm) {
                AvatarImageView(
                    localPreview: nil,
                    avatarBase64: author?.avatarBase64,
                    avatarURL: author?.avatarURL,
                    size: 36
                )
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(authorDisplayName)
                        .font(CLTypography.subheadline.weight(.semibold))
                        .foregroundStyle(CLColor.ink)
                        .lineLimit(1)

                    Text(post.createdAt, format: .relative(presentation: .named))
                        .font(CLTypography.caption)
                        .foregroundStyle(CLColor.inkMuted)
                        .lineLimit(1)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    "\(authorDisplayName), \(post.createdAt.formatted(.relative(presentation: .named)))"
                )

                Spacer()
                if canManage {
                    Menu {
                        Button("Edit", action: onEdit)
                        Button("Delete", role: .destructive, action: onDelete)
                    } label: { Image(systemName: "ellipsis").foregroundStyle(CLColor.inkSecondary) }
                    .accessibilityLabel("Post actions")
                }
            }
            if let text = post.text { Text(text).font(CLTypography.body).foregroundStyle(CLColor.ink).fixedSize(horizontal: false, vertical: true) }
            if let url = post.imageURL { CommunityPostImage(url: url).frame(height: 220) }
        }
        .padding(CLSpacing.md)
        .background(CLColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: CLRadius.lg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: CLRadius.lg, style: .continuous).stroke(CLColor.hairline, lineWidth: 1))
    }

    private var authorDisplayName: String {
        guard let name = author?.displayName.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else { return "Member" }
        return name
    }
}

struct CommunityPostImage: View {
    let url: URL
    var body: some View {
        AsyncImage(url: url) { phase in
            if case let .success(image) = phase {
                image.resizable().scaledToFill()
            } else { CLColor.surfaceSoft.overlay { ProgressView().tint(CLColor.primary) } }
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous))
    }
}
