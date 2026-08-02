import SwiftUI
import UIKit

/// Warm post card: author row, optional text, generous image when present.
struct CommunityPostCardView: View {
    let item: CommunityPostItem
    let currentUserId: String?
    let isDeleting: Bool
    let onAuthorTap: (String) -> Void
    let onDelete: () -> Void

    private var displayName: String {
        let name = item.author?.displayName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? "Member" : name
    }

    private var isOwnPost: Bool {
        item.post.authorId == currentUserId
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CLSpacing.sm) {
            authorRow

            if let text = item.post.text, !text.isEmpty {
                Text(text)
                    .font(CLTypography.body)
                    .foregroundStyle(CLColor.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let imageURL = item.post.imageURL {
                RemotePostImageView(url: imageURL)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 180, maxHeight: 280)
                    .clipShape(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous))
                    .accessibilityLabel("Post photo")
            }

            Text(item.post.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(CLTypography.footnote)
                .foregroundStyle(CLColor.inkMuted)
        }
        .clCardStyle()
        .clAppear()
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var authorRow: some View {
        HStack(spacing: CLSpacing.sm) {
            let isSelf = item.post.authorId == currentUserId

            if isSelf {
                authorIdentity
            } else {
                Button {
                    onAuthorTap(item.post.authorId)
                } label: {
                    authorIdentity
                }
                .buttonStyle(.plain)
                .accessibilityLabel("View profile for \(displayName)")
                .accessibilityHint("Opens member profile")
            }

            Spacer(minLength: 0)

            if isOwnPost {
                if isDeleting {
                    ProgressView()
                        .tint(CLColor.inkMuted)
                } else {
                    Menu {
                        Button("Delete Post", role: .destructive, action: onDelete)
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(CLColor.inkMuted)
                            .frame(width: AccessibilityHelpers.minimumTouchTarget,
                                   height: AccessibilityHelpers.minimumTouchTarget)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Post options")
                }
            }
        }
    }

    private var authorIdentity: some View {
        HStack(spacing: CLSpacing.sm) {
            AvatarImageView(
                localPreview: nil,
                avatarBase64: item.author?.avatarBase64,
                avatarURL: item.author?.avatarURL,
                size: 40
            )

            Text(displayName)
                .font(CLTypography.headline)
                .foregroundStyle(CLColor.ink)
                .lineLimit(1)
        }
    }
}

// MARK: - Remote image

private struct RemotePostImageView: View {
    let url: URL
    var imageLoader: any ImageLoading = ImageLoader.shared

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            CLColor.surfaceSoft

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ProgressView()
                    .tint(CLColor.primary)
            }
        }
        .task(id: url) {
            image = try? await imageLoader.load(from: url)
        }
    }
}
