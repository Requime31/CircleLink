import SwiftUI
import UIKit

/// Full-width vertical list of profile posts (text and/or image).
///
/// Lives inside `ProfileView`'s `ScrollView` — do **not** wrap in another
/// `ScrollView` (nested scrolls fight over gestures).
///
/// Uses plain `VStack` (not `LazyVStack`): the parent profile body is a
/// regular `VStack`, so laziness would not apply anyway. Fine for a
/// small number of profile posts.
///
/// Images use a **fixed aspect ratio** so remote images cannot expand to
/// full pixel height and push the rest of the profile off-screen.
struct ProfilePostsListView: View {
    let posts: [ProfilePost]
    let author: User
    let localAvatarPreview: UIImage?
    let onDelete: (ProfilePost) -> Void
    var onEdit: ((ProfilePost) -> Void)? = nil

    @State private var postPendingDelete: ProfilePost?

    private var displayablePosts: [ProfilePost] {
        posts.filter { post in
            let hasText = !(post.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            return hasText || post.imageURL != nil
        }
    }

    var body: some View {
        VStack(spacing: CLSpacing.md) {
            ForEach(displayablePosts) { post in
                ProfilePostCardView(
                    post: post,
                    author: author,
                    localAvatarPreview: localAvatarPreview,
                    onEdit: onEdit,
                    onDeleteRequest: { postPendingDelete = post }
                )
            }
        }
        .accessibilityElement(children: .contain)
        .confirmationDialog(
            "Delete this post?",
            isPresented: Binding(
                get: { postPendingDelete != nil },
                set: { if !$0 { postPendingDelete = nil } }
            ),
            titleVisibility: .visible,
            presenting: postPendingDelete
        ) { post in
            Button("Delete Post", role: .destructive) {
                onDelete(post)
                postPendingDelete = nil
            }
            Button("Cancel", role: .cancel) {
                postPendingDelete = nil
            }
        } message: { _ in
            Text("This can’t be undone.")
        }
    }
}

// MARK: - Card

private struct ProfilePostCardView: View {
    let post: ProfilePost
    let author: User
    let localAvatarPreview: UIImage?
    var onEdit: ((ProfilePost) -> Void)?
    let onDeleteRequest: () -> Void

    private var trimmedText: String? {
        guard let text = post.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            return nil
        }
        return text
    }

    private var authorName: String {
        let name = author.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Member" : name
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CLSpacing.sm) {
            header

            Group {
                if let trimmedText {
                    Text(trimmedText)
                        .font(CLTypography.body)
                        .foregroundStyle(CLColor.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(8)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let url = post.imageURL {
                    ProfilePostImageView(url: url)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(contentAccessibilityLabel)
        }
        .padding(CLSpacing.md)
        .background(CLColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: CLRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CLRadius.lg, style: .continuous)
                .stroke(CLColor.hairline, lineWidth: 1)
        )
    }

    private var header: some View {
        HStack(alignment: .center, spacing: CLSpacing.sm) {
            AvatarImageView(
                localPreview: localAvatarPreview,
                avatarBase64: author.avatarBase64,
                avatarURL: author.avatarURL,
                size: 36
            )
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(authorName)
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
                "\(authorName), \(post.createdAt.formatted(.relative(presentation: .named)))"
            )

            Spacer(minLength: CLSpacing.xs)

            Menu {
                if let onEdit {
                    Button("Edit Post") {
                        onEdit(post)
                    }
                }

                Button("Delete Post", role: .destructive) {
                    onDeleteRequest()
                }
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

    private var contentAccessibilityLabel: String {
        if let trimmedText {
            return post.imageURL != nil ? "Post with photo: \(trimmedText)" : "Post: \(trimmedText)"
        }
        if post.imageURL != nil {
            return "Photo post"
        }
        return "Post"
    }
}

// MARK: - Image

private struct ProfilePostImageView: View {
    let url: URL

    @State private var image: UIImage?
    @State private var didFail = false

    var body: some View {
        Color.clear
            .aspectRatio(4 / 3, contentMode: .fit)
            .overlay {
                Group {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else if didFail {
                        placeholder
                    } else {
                        CLColor.surfaceSoft
                            .overlay { ProgressView().tint(CLColor.primary) }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous))
            .accessibilityHidden(true)
            .task(id: url) {
                await load()
            }
    }

    private var placeholder: some View {
        ZStack {
            CLColor.surfaceSoft
            Image(systemName: "photo")
                .font(.title2)
                .foregroundStyle(CLColor.inkMuted)
        }
    }

    private func load() async {
        didFail = false
        image = nil
        do {
            let loaded = try await ImageLoader.shared.load(from: url)
            guard !Task.isCancelled else { return }
            image = loaded
            didFail = loaded == nil
        } catch {
            guard !Task.isCancelled else { return }
            didFail = true
        }
    }
}
