import SwiftUI

struct PostLikeContext {
    let store: PostLikeStore
    let service: PostLikeService
    let users: UserRepository
    let moderation: ModerationRepository
    let currentUserId: () -> String?
    let peerProfile: (String) -> AnyView
}
private struct PostLikeContextKey: EnvironmentKey {
    static let defaultValue: PostLikeContext? = nil
}
extension EnvironmentValues {
    var postLikeContext: PostLikeContext? {
        get { self[PostLikeContextKey.self] }
        set { self[PostLikeContextKey.self] = newValue }
    }
}

struct PostLikeBar: View {
    let post: PostReference
    @Environment(\.postLikeContext) private var context
    var body: some View {
        if let context, let userId = context.currentUserId() {
            ConnectedPostLikeBar(post: post, userId: userId, context: context, store: context.store)
                // Use the surrounding card spacing while preserving 44-point hit targets.
                .padding(.vertical, -10)
        }
    }
}
private struct ConnectedPostLikeBar: View {
    let post: PostReference
    let userId: String
    let context: PostLikeContext
    @ObservedObject var store: PostLikeStore
    @State private var showPeople = false
    @ScaledMetric(relativeTo: .body) private var heartSize: CGFloat = 20
    private var key: PostLikeStore.Key { .init(post: post, userId: userId) }
    var body: some View {
        let state = store.state(key)
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                Button { Task { await store.toggle(key) } } label: {
                    Image(systemName: state.isLiked ? "heart.fill" : "heart")
                        .font(.system(size: heartSize))
                        .frame(width: heartSize)
                        .foregroundStyle(state.isLiked ? CLColor.primary : CLColor.inkSecondary)
                        .padding(.trailing, 4)
                        .frame(minWidth: AccessibilityHelpers.minimumTouchTarget, minHeight: AccessibilityHelpers.minimumTouchTarget, alignment: .trailing)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(state.isLiked ? "Unlike post" : "Like post")
                .accessibilityValue(state.isLiked ? "Liked" : "Not liked")
                .disabled(!state.ready || !state.snapshot.exists || state.pending != nil)
                Button { showPeople = true } label: {
                    Text(state.count, format: .number)
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(CLColor.inkSecondary)
                        .frame(minWidth: AccessibilityHelpers.minimumTouchTarget, minHeight: AccessibilityHelpers.minimumTouchTarget, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("\(state.count) likes")
                .accessibilityHint("Shows people who liked this post")
                .disabled(!state.snapshot.exists)
                Spacer(minLength: 0)
            }
            .clGuideTarget(
                .communityReactions, instance: post.id,
                enabled: post.kind == .community && state.ready && state.snapshot.exists && state.pending == nil
            )
            .buttonStyle(.plain)
            // Inset the visible heart 6 points from the media edge, independently of its hit area.
            .padding(.leading, 6 - max(0, AccessibilityHelpers.minimumTouchTarget - heartSize - 4))
            if let error = state.error {
                Text(error).font(.footnote).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if !state.ready {
                    Button("Retry") { store.retryObservation(key) }.frame(minWidth: 44, minHeight: 44)
                }
            }
        }
        .task(id: key) {
            let subscribedKey = key
            store.retain(subscribedKey)
            defer { store.release(subscribedKey) }
            do { try await Task.sleep(for: .seconds(315_360_000)) } catch {}
        }
        .clGuidePresentationBlocked(showPeople)
        .sheet(isPresented: $showPeople) {
            PostLikersView(post: post, context: context)
        }
    }
}

private struct PostLikersView: View {
    let post: PostReference
    let context: PostLikeContext
    @Environment(\.dismiss) private var dismiss
    @State private var users: [User] = []
    @State private var cursor: String?
    @State private var hasMore = true
    @State private var loading = false
    @State private var error: String?
    @State private var selectedUser: User?
    var body: some View {
        NavigationStack {
            List {
                ForEach(users) { user in
                    Button { Task { await select(user) } } label: {
                        HStack {
                            AvatarImageView(localPreview: nil, avatarBase64: user.avatarBase64, avatarURL: user.avatarURL, size: 40)
                                .accessibilityHidden(true)
                            Text(user.displayName).font(.body).fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(minHeight: 44)
                    }
                    .accessibilityLabel("View profile for \(user.displayName)")
                }
                if let error { Text(error).font(.body) }
                if loading { ProgressView().accessibilityLabel("Loading likes") }
                if hasMore && !loading {
                    Button("Load more") { Task { await load() } }.frame(minHeight: 44)
                }
                if users.isEmpty && !loading && !hasMore { Text("No available profiles to show.") }
            }
            .navigationTitle("Likes")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .task { await load() }
            .refreshable { users = []; cursor = nil; hasMore = true; await load() }
            .task(id: Set(users.map(\.id))) {
                do {
                    for try await user in context.users.observeProfiles(userIds: Set(users.map(\.id))) {
                        guard !Task.isCancelled else { return }
                        if !user.isSociallyAvailable { users.removeAll { $0.id == user.id } }
                        else if let index = users.firstIndex(where: { $0.id == user.id }) { users[index] = user }
                    }
                } catch { /* Selection still validates availability against the server. */ }
            }
            .sheet(item: $selectedUser, onDismiss: {
                Task { users = []; cursor = nil; hasMore = true; await load() }
            }) { context.peerProfile($0.id) }
        }
    }
    private func load() async {
        guard !loading, hasMore else { return }
        loading = true
        defer { loading = false }
        do {
            let blocked = try await context.moderation.fetchBlockedUserIds()
            let ids = try await context.service.likerIds(post: post, after: cursor, limit: 50)
            var next: [User] = []
            for id in ids where !blocked.contains(id) {
                guard let viewerId = context.currentUserId(),
                      try await context.service.canNavigate(userId: id, viewerId: viewerId) else { continue }
                if let user = try? await context.users.fetchProfile(userId: id), user.isSociallyAvailable { next.append(user) }
            }
            users.removeAll { blocked.contains($0.id) }
            users += next.filter { nextUser in !users.contains(where: { $0.id == nextUser.id }) }
            cursor = ids.last ?? cursor
            hasMore = ids.count == 50
            error = nil
        } catch { self.error = "Couldn’t load likes. Please try again." }
    }
    private func select(_ user: User) async {
        do {
            let blocked = try await context.moderation.fetchBlockedUserIds()
            let fresh = try await context.users.fetchProfile(userId: user.id)
            guard let viewerId = context.currentUserId(),
                  try await context.service.canNavigate(userId: user.id, viewerId: viewerId),
                  !blocked.contains(user.id), fresh.isSociallyAvailable else {
                users.removeAll { $0.id == user.id }; return
            }
            selectedUser = fresh
        } catch { self.error = "This profile is unavailable." }
    }
}
