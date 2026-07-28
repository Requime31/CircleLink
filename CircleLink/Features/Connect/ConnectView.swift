import SwiftUI

struct ConnectView: View {
    @ObservedObject var viewModel: ConnectViewModel

    @State private var reportTarget: ModerationTarget?
    @State private var blockTarget: ModerationTarget?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    if let moderationMessage = viewModel.moderationMessage {
                        HStack(alignment: .top, spacing: CLSpacing.sm) {
                            Text(moderationMessage)
                                .font(CLTypography.caption)
                                .foregroundStyle(CLColor.ink)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .accessibilityLabel(moderationMessage)
                            Button("Dismiss") {
                                viewModel.clearModerationFeedback()
                            }
                            .font(CLTypography.caption)
                            .foregroundStyle(CLColor.primary)
                            .accessibilityLabel("Dismiss moderation message")
                        }
                    }

                    if let actionErrorMessage = viewModel.actionErrorMessage {
                        Text(actionErrorMessage)
                            .font(CLTypography.caption)
                            .foregroundStyle(CLColor.error)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityLabel("Connect error: \(actionErrorMessage)")
                    }

                    communityPickerSection
                    candidatesSection
                    incomingSection
                    matchedSection
                }
                .padding(CLSpacing.base)
            }
            .background(CLColor.canvas)
            .navigationTitle("Connect")
            .task {
                await viewModel.load()
            }
            .refreshable {
                await viewModel.load()
            }
            .confirmationDialog(
                "Why are you reporting this user?",
                isPresented: Binding(
                    get: { reportTarget != nil },
                    set: { if !$0 { reportTarget = nil } }
                ),
                titleVisibility: .visible
            ) {
                if let reportTarget {
                    ForEach(ReportReason.allCases, id: \.self) { reason in
                        Button(reason.title) {
                            Task {
                                await viewModel.report(userId: reportTarget.userId, reason: reason)
                            }
                        }
                    }
                }
                Button("Cancel", role: .cancel) {
                    reportTarget = nil
                }
            }
            .confirmationDialog(
                blockConfirmTitle,
                isPresented: Binding(
                    get: { blockTarget != nil },
                    set: { if !$0 { blockTarget = nil } }
                ),
                titleVisibility: .visible
            ) {
                if let blockTarget {
                    Button("Block", role: .destructive) {
                        Task {
                            await viewModel.block(userId: blockTarget.userId)
                        }
                    }
                }
                Button("Cancel", role: .cancel) {
                    blockTarget = nil
                }
            }
        }
    }

    private var blockConfirmTitle: String {
        if let name = blockTarget?.displayName {
            return "Block \(name)? They won’t appear in Connect for you."
        }
        return "Block this user? They won’t appear in Connect for you."
    }

    // MARK: - Community picker

    @ViewBuilder
    private var communityPickerSection: some View {
        VStack(alignment: .leading, spacing: CLSpacing.md) {
            Text("Community")
                .font(CLTypography.section)
                .foregroundStyle(CLColor.ink)

            switch viewModel.communitiesState {
            case .idle, .loading:
                ProgressView("Loading communities…")
                    .tint(CLColor.primary)
            case .empty:
                CLEmptyState(
                    systemImage: "person.3",
                    title: "Join a community first",
                    message: "Pick a community on the Communities tab, then come back to find people."
                )
                .frame(maxHeight: 220)
            case let .error(message):
                sectionError(message) {
                    Task { await viewModel.load() }
                }
            case let .loaded(communities):
                Menu {
                    ForEach(communities) { community in
                        Button(community.name) {
                            Task { await viewModel.selectCommunity(community.id) }
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedCommunityName(from: communities))
                            .font(CLTypography.bodyMedium)
                            .foregroundStyle(CLColor.ink)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(CLColor.muted)
                    }
                    .padding(.horizontal, CLSpacing.base)
                    .frame(height: 48)
                    .background(CLColor.surfaceSoft)
                    .clipShape(RoundedRectangle(cornerRadius: CLRadius.md))
                }
                .accessibilityLabel("Select community")
            }
        }
    }

    // MARK: - Candidates

    @ViewBuilder
    private var candidatesSection: some View {
        VStack(alignment: .leading, spacing: CLSpacing.md) {
            Text("People nearby")
                .font(CLTypography.section)
                .foregroundStyle(CLColor.ink)

            if viewModel.selectedCommunityId == nil {
                Text("Select a community to see candidates.")
                    .font(CLTypography.callout)
                    .foregroundStyle(CLColor.muted)
            } else {
                switch viewModel.candidatesState {
                case .idle, .loading:
                    ProgressView("Loading candidates…")
                        .tint(CLColor.primary)
                case .empty:
                    Text("No new people to connect with here.")
                        .font(CLTypography.callout)
                        .foregroundStyle(CLColor.muted)
                case let .error(message):
                    sectionError(message) {
                        if let communityId = viewModel.selectedCommunityId {
                            Task { await viewModel.selectCommunity(communityId) }
                        }
                    }
                case let .loaded(candidates):
                    LazyVStack(spacing: CLSpacing.md) {
                        ForEach(candidates) { user in
                            CandidateRowView(
                                user: user,
                                isConnecting: viewModel.connectingUserId == user.id
                            ) {
                                Task { await viewModel.sendConnect(to: user.id) }
                            }
                            .contextMenu {
                                Button("Report…") {
                                    reportTarget = ModerationTarget(
                                        userId: user.id,
                                        displayName: user.displayName
                                    )
                                }
                                Button("Block…", role: .destructive) {
                                    blockTarget = ModerationTarget(
                                        userId: user.id,
                                        displayName: user.displayName
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Incoming

    @ViewBuilder
    private var incomingSection: some View {
        VStack(alignment: .leading, spacing: CLSpacing.md) {
            Text("Incoming requests")
                .font(CLTypography.section)
                .foregroundStyle(CLColor.ink)

            switch viewModel.incomingState {
            case .idle, .loading:
                ProgressView("Loading requests…")
                    .tint(CLColor.primary)
            case .empty:
                Text("No pending requests.")
                    .font(CLTypography.callout)
                    .foregroundStyle(CLColor.muted)
            case let .error(message):
                sectionError(message) {
                    Task { await viewModel.load() }
                }
            case let .loaded(items):
                LazyVStack(spacing: CLSpacing.md) {
                    ForEach(items) { item in
                        IncomingRequestRowView(
                            item: item,
                            isResponding: viewModel.respondingRequestId == item.id,
                            onAccept: {
                                Task {
                                    await viewModel.accept(
                                        requestId: item.request.id,
                                        fromUserId: item.request.fromUserId
                                    )
                                }
                            },
                            onDecline: {
                                Task { await viewModel.decline(requestId: item.request.id) }
                            }
                        )
                        .contextMenu {
                            Button("Report…") {
                                reportTarget = ModerationTarget(
                                    userId: item.peer.id,
                                    displayName: item.peer.displayName
                                )
                            }
                            Button("Block…", role: .destructive) {
                                blockTarget = ModerationTarget(
                                    userId: item.peer.id,
                                    displayName: item.peer.displayName
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Matched

    @ViewBuilder
    private var matchedSection: some View {
        VStack(alignment: .leading, spacing: CLSpacing.md) {
            Text("Matched")
                .font(CLTypography.section)
                .foregroundStyle(CLColor.ink)

            switch viewModel.matchedState {
            case .idle, .loading:
                ProgressView("Loading matches…")
                    .tint(CLColor.primary)
            case .empty:
                Text("Accepted connections will show here.")
                    .font(CLTypography.callout)
                    .foregroundStyle(CLColor.muted)
            case let .error(message):
                sectionError(message) {
                    Task { await viewModel.load() }
                }
            case let .loaded(items):
                LazyVStack(spacing: CLSpacing.md) {
                    ForEach(items) { item in
                        MatchedRowView(
                            item: item,
                            isOpening: viewModel.openingChatPeerId == item.peer.id
                        ) {
                            Task { await viewModel.openChat(with: item.peer.id) }
                        }
                        .contextMenu {
                            Button("Report…") {
                                reportTarget = ModerationTarget(
                                    userId: item.peer.id,
                                    displayName: item.peer.displayName
                                )
                            }
                            Button("Block…", role: .destructive) {
                                blockTarget = ModerationTarget(
                                    userId: item.peer.id,
                                    displayName: item.peer.displayName
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    private func selectedCommunityName(from communities: [Community]) -> String {
        communities.first(where: { $0.id == viewModel.selectedCommunityId })?.name
            ?? "Select community"
    }

    private func sectionError(_ message: String, retry: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: CLSpacing.sm) {
            Text(message)
                .font(CLTypography.callout)
                .foregroundStyle(CLColor.muted)
                .accessibilityLabel("Error: \(message)")
            Button("Retry", action: retry)
                .font(CLTypography.buttonSmall)
                .foregroundStyle(CLColor.primary)
                .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
                .accessibilityLabel("Retry loading section")
        }
    }
}

// MARK: - Moderation target

private struct ModerationTarget: Identifiable, Equatable {
    let userId: String
    let displayName: String

    var id: String { userId }
}

// MARK: - Rows

private struct CandidateRowView: View {
    let user: User
    let isConnecting: Bool
    let onConnect: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: CLSpacing.md) {
            AvatarImageView(
                localPreview: nil,
                avatarBase64: user.avatarBase64,
                avatarURL: user.avatarURL,
                size: 52
            )

            VStack(alignment: .leading, spacing: CLSpacing.xs) {
                Text(user.displayName)
                    .font(CLTypography.section)
                    .foregroundStyle(CLColor.ink)
                    .lineLimit(1)

                if !user.interests.isEmpty {
                    Text(user.interests.prefix(3).joined(separator: " · "))
                        .font(CLTypography.caption)
                        .foregroundStyle(CLColor.muted)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: CLSpacing.sm)

            Button(action: onConnect) {
                if isConnecting {
                    ProgressView()
                        .frame(width: 88, height: AccessibilityHelpers.minimumTouchTarget)
                } else {
                    Text("Connect")
                        .font(CLTypography.buttonSmall)
                        .frame(width: 88, height: AccessibilityHelpers.minimumTouchTarget)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(CLColor.primary)
            .disabled(isConnecting)
            .accessibilityLabel("Connect with \(user.displayName)")
        }
        .padding(CLSpacing.md)
        .background(CLColor.surfaceSoft)
        .clipShape(RoundedRectangle(cornerRadius: CLRadius.md))
    }
}

private struct IncomingRequestRowView: View {
    let item: ConnectRequestItem
    let isResponding: Bool
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: CLSpacing.md) {
            HStack(spacing: CLSpacing.md) {
                AvatarImageView(
                    localPreview: nil,
                    avatarBase64: item.peer.avatarBase64,
                    avatarURL: item.peer.avatarURL,
                    size: 52
                )

                VStack(alignment: .leading, spacing: CLSpacing.xs) {
                    Text(item.peer.displayName)
                        .font(CLTypography.section)
                        .foregroundStyle(CLColor.ink)

                    if !item.peer.interests.isEmpty {
                        Text(item.peer.interests.prefix(3).joined(separator: " · "))
                            .font(CLTypography.caption)
                            .foregroundStyle(CLColor.muted)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: CLSpacing.md) {
                Button(action: onDecline) {
                    if isResponding {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
                    } else {
                        Text("Decline")
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
                    }
                }
                .buttonStyle(.bordered)
                .tint(CLColor.ink)
                .disabled(isResponding)
                .accessibilityLabel("Decline \(item.peer.displayName)")

                Button(action: onAccept) {
                    if isResponding {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
                    } else {
                        Text("Accept")
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(CLColor.primary)
                .disabled(isResponding)
                .accessibilityLabel("Accept \(item.peer.displayName)")
            }
        }
        .padding(CLSpacing.md)
        .background(CLColor.surfaceSoft)
        .clipShape(RoundedRectangle(cornerRadius: CLRadius.md))
    }
}

private struct MatchedRowView: View {
    let item: MatchedConnectionItem
    let isOpening: Bool
    let onOpenChat: () -> Void

    var body: some View {
        HStack(spacing: CLSpacing.md) {
            AvatarImageView(
                localPreview: nil,
                avatarBase64: item.peer.avatarBase64,
                avatarURL: item.peer.avatarURL,
                size: 52
            )

            VStack(alignment: .leading, spacing: CLSpacing.xs) {
                Text(item.peer.displayName)
                    .font(CLTypography.section)
                    .foregroundStyle(CLColor.ink)

                Text("Connected")
                    .font(CLTypography.caption)
                    .foregroundStyle(CLColor.muted)
            }

            Spacer(minLength: CLSpacing.sm)

            Button(action: onOpenChat) {
                if isOpening {
                    ProgressView()
                        .frame(width: 100, height: AccessibilityHelpers.minimumTouchTarget)
                } else {
                    Text("Open Chat")
                        .font(CLTypography.buttonSmall)
                        .frame(width: 100, height: AccessibilityHelpers.minimumTouchTarget)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(CLColor.primary)
            .disabled(isOpening)
            .accessibilityLabel("Open chat with \(item.peer.displayName)")
        }
        .padding(CLSpacing.md)
        .background(CLColor.surfaceSoft)
        .clipShape(RoundedRectangle(cornerRadius: CLRadius.md))
    }
}
