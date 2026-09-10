import SwiftUI

struct PostActivityDetailView: View {
    let reference: PostReference
    let repository: FirestorePostActivityRepository
    @Environment(\.postLikeContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var content: PostActivityContent?
    @State private var unavailable = false
    @State private var peer: User?
    @State private var media: IdentifiedURL?
    var body: some View {
        NavigationStack {
            ScrollView {
                if let content {
                    if let post = content.community {
                        CommunityPostCard(post: post, author: content.author, canManage: false,
                            currentUserId: context?.currentUserId(),
                            onSelectAuthor: { _ in peer = content.author },
                            onSelectMedia: { media = IdentifiedURL($0) }, onEdit: {}, onDelete: {})
                    } else if let post = content.profile {
                        ProfilePostsListView(posts: [post], author: content.author, localAvatarPreview: nil,
                            currentUserId: context?.currentUserId(), onSelectAuthor: { _ in peer = content.author })
                    }
                } else if unavailable {
                    Text("This post is unavailable.").font(.body).padding()
                } else { ProgressView().padding() }
            }
            .navigationTitle("Post")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .task(id: reference) {
                do {
                    let loaded = try await repository.fetch(reference)
                    let blocked = try await context?.moderation.fetchBlockedUserIds() ?? []
                    guard let context, let viewerId = context.currentUserId(),
                          try await context.service.canNavigate(userId: loaded.author.id, viewerId: viewerId),
                          !blocked.contains(loaded.author.id) else { unavailable = true; return }
                    content = loaded
                    for try await count in context.service.observeCount(post: reference) {
                        guard !Task.isCancelled else { return }
                        if count == nil { content = nil; unavailable = true; return }
                    }
                } catch { content = nil; unavailable = true }
            }
            .fullScreenCover(item: $media) { ChatMediaFullscreenView(url: $0.url) }
            .sheet(item: $peer) { user in context?.peerProfile(user.id) }
        }
    }
}
