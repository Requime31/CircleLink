import SwiftUI

/// Feed block inside Community detail — membership-gated read + compose CTA.
struct CommunityFeedSection: View {
    @ObservedObject var feedViewModel: CommunityFeedViewModel
    let isMember: Bool
    let onJoinTapped: () -> Void
    let onComposeTapped: () -> Void
    let onAuthorTap: (String) -> Void
    let onDelete: (CommunityPostItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: CLSpacing.sm) {
            header

            if let errorMessage = feedViewModel.errorMessage {
                Text(errorMessage)
                    .font(CLTypography.footnote)
                    .foregroundStyle(CLColor.error)
                    .padding(CLSpacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(CLColor.errorSoft)
                    .clipShape(RoundedRectangle(cornerRadius: CLRadius.sm, style: .continuous))
                    .accessibilityLabel("Feed error: \(errorMessage)")
            }

            content
        }
    }

    @ViewBuilder
    private var header: some View {
        HStack {
            Text("Posts")
                .font(CLTypography.headline)
                .foregroundStyle(CLColor.ink)
                .accessibilityAddTraits(.isHeader)

            Spacer()

            if isMember {
                Button(action: onComposeTapped) {
                    Label("New Post", systemImage: "square.and.pencil")
                        .font(CLTypography.subheadline.weight(.semibold))
                }
                .foregroundStyle(CLColor.ink)
                .accessibilityLabel("Create new post")
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if !isMember {
            joinRequiredState
        } else {
            switch feedViewModel.feedState {
            case .idle, .loading:
                ProgressView("Loading posts…")
                    .tint(CLColor.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, CLSpacing.md)
            case .empty:
                emptyMemberState
            case let .error(message):
                VStack(alignment: .leading, spacing: CLSpacing.sm) {
                    Text(message)
                        .font(CLTypography.subheadline)
                        .foregroundStyle(CLColor.inkSecondary)
                    Button("Retry") {
                        feedViewModel.reload()
                    }
                    .buttonStyle(CLSecondaryButtonStyle())
                    .accessibilityLabel("Retry loading posts")
                }
            case .loaded:
                postsList
            }
        }
    }

    private var joinRequiredState: some View {
        VStack(alignment: .leading, spacing: CLSpacing.sm) {
            Text("Join to see posts and share with this community.")
                .font(CLTypography.subheadline)
                .foregroundStyle(CLColor.inkMuted)
            Button("Join Community", action: onJoinTapped)
                .buttonStyle(CLPrimaryButtonStyle())
                .accessibilityLabel("Join community to see posts")
        }
        .padding(CLSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CLColor.tintCream)
        .clipShape(RoundedRectangle(cornerRadius: CLRadius.lg, style: .continuous))
    }

    private var emptyMemberState: some View {
        VStack(alignment: .leading, spacing: CLSpacing.sm) {
            Text("No posts yet")
                .font(CLTypography.title2)
                .foregroundStyle(CLColor.ink)
            Text("Be the first to share something warm with this community.")
                .font(CLTypography.subheadline)
                .foregroundStyle(CLColor.inkMuted)
            Button("Be the first to post", action: onComposeTapped)
                .buttonStyle(CLPrimaryButtonStyle(fillsWidth: false))
                .padding(.top, CLSpacing.xxs)
                .accessibilityLabel("Be the first to post")
        }
        .padding(CLSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CLColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: CLRadius.lg, style: .continuous))
        .shadow(color: CLShadow.cardColor, radius: CLShadow.cardRadius, x: 0, y: CLShadow.cardY)
    }

    private var postsList: some View {
        LazyVStack(spacing: CLSpacing.md) {
            ForEach(feedViewModel.items) { item in
                CommunityPostCardView(
                    item: item,
                    currentUserId: feedViewModel.currentUserId,
                    isDeleting: feedViewModel.deletingPostId == item.id,
                    onAuthorTap: onAuthorTap,
                    onDelete: { onDelete(item) }
                )
                .onAppear {
                    feedViewModel.loadMoreIfNeeded(currentItem: item)
                }
            }

            if feedViewModel.isLoadingMore {
                ProgressView()
                    .tint(CLColor.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, CLSpacing.sm)
            }
        }
    }
}
