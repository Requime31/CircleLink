import SwiftUI

struct ConnectView: View {
    @ObservedObject var viewModel: ConnectViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CLSpacing.lg) {
                    if let actionErrorMessage = viewModel.actionErrorMessage {
                        Text(actionErrorMessage)
                            .font(CLTypography.footnote)
                            .foregroundStyle(CLColor.error)
                            .padding(CLSpacing.sm)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(CLColor.errorSoft)
                            .clipShape(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous))
                            .accessibilityLabel("Connect error: \(actionErrorMessage)")
                    }

                    communityPickerSection
                    candidatesSection
                    incomingSection
                    matchedSection
                }
                .padding(.horizontal, CLSpacing.md)
                .padding(.vertical, CLSpacing.md)
            }
            .clCanvasBackground()
            .navigationTitle("Connect")
            .task {
                await viewModel.load()
            }
            .refreshable {
                await viewModel.load()
            }
        }
    }

    // MARK: - Community picker

    @ViewBuilder
    private var communityPickerSection: some View {
        VStack(alignment: .leading, spacing: CLSpacing.sm) {
            Text("Community")
                .font(CLTypography.headline)
                .foregroundStyle(CLColor.ink)

            switch viewModel.communitiesState {
            case .idle, .loading:
                ProgressView("Loading communities…")
                    .tint(CLColor.primary)
                    .foregroundStyle(CLColor.inkMuted)
            case .empty:
                Text("Join a community first to find people.")
                    .font(CLTypography.subheadline)
                    .foregroundStyle(CLColor.inkMuted)
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
                            .font(CLTypography.body.weight(.medium))
                            .foregroundStyle(CLColor.ink)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(CLColor.inkMuted)
                            .accessibilityHidden(true)
                    }
                    .padding(.horizontal, CLSpacing.md)
                    .frame(height: 48)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(CLColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous)
                            .stroke(CLColor.hairline, lineWidth: 1)
                    )
                }
                .accessibilityLabel("Select community")
            }
        }
    }

    // MARK: - Candidates

    @ViewBuilder
    private var candidatesSection: some View {
        VStack(alignment: .leading, spacing: CLSpacing.sm) {
            Text("People nearby")
                .font(CLTypography.headline)
                .foregroundStyle(CLColor.ink)

            if viewModel.selectedCommunityId == nil {
                Text("Select a community to see candidates.")
                    .font(CLTypography.subheadline)
                    .foregroundStyle(CLColor.inkMuted)
            } else {
                switch viewModel.candidatesState {
                case .idle, .loading:
                    ProgressView("Loading candidates…")
                        .tint(CLColor.primary)
                        .foregroundStyle(CLColor.inkMuted)
                case .empty:
                    Text("No new people to connect with here.")
                        .font(CLTypography.subheadline)
                        .foregroundStyle(CLColor.inkMuted)
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
                            .clAppear()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Incoming

    @ViewBuilder
    private var incomingSection: some View {
        VStack(alignment: .leading, spacing: CLSpacing.sm) {
            Text("Incoming requests")
                .font(CLTypography.headline)
                .foregroundStyle(CLColor.ink)

            switch viewModel.incomingState {
            case .idle, .loading:
                ProgressView("Loading requests…")
                    .tint(CLColor.primary)
                    .foregroundStyle(CLColor.inkMuted)
            case .empty:
                Text("No pending requests.")
                    .font(CLTypography.subheadline)
                    .foregroundStyle(CLColor.inkMuted)
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
                    }
                }
            }
        }
    }

    // MARK: - Matched

    @ViewBuilder
    private var matchedSection: some View {
        VStack(alignment: .leading, spacing: CLSpacing.sm) {
            Text("Matched")
                .font(CLTypography.headline)
                .foregroundStyle(CLColor.ink)

            switch viewModel.matchedState {
            case .idle, .loading:
                ProgressView("Loading matches…")
                    .tint(CLColor.primary)
                    .foregroundStyle(CLColor.inkMuted)
            case .empty:
                Text("Accepted connections will show here.")
                    .font(CLTypography.subheadline)
                    .foregroundStyle(CLColor.inkMuted)
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
        VStack(alignment: .leading, spacing: CLSpacing.xs) {
            Text(message)
                .font(CLTypography.subheadline)
                .foregroundStyle(CLColor.inkSecondary)
                .accessibilityLabel("Error: \(message)")
            Button("Retry", action: retry)
                .font(CLTypography.subheadline.weight(.medium))
                .foregroundStyle(CLColor.primaryPressed)
                .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
                .accessibilityLabel("Retry loading section")
        }
    }
}

// MARK: - Rows

private struct CandidateRowView: View {
    let user: User
    let isConnecting: Bool
    let onConnect: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: CLSpacing.sm) {
            AvatarImageView(
                localPreview: nil,
                avatarBase64: user.avatarBase64,
                avatarURL: user.avatarURL,
                size: 52
            )

            VStack(alignment: .leading, spacing: CLSpacing.xxs) {
                Text(user.displayName)
                    .font(CLTypography.headline)
                    .foregroundStyle(CLColor.ink)
                    .lineLimit(1)

                if !user.interests.isEmpty {
                    Text(user.interests.prefix(3).joined(separator: " · "))
                        .font(CLTypography.footnote)
                        .foregroundStyle(CLColor.inkMuted)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: CLSpacing.xs)

            Button(action: onConnect) {
                if isConnecting {
                    ProgressView()
                        .tint(CLColor.onPrimary)
                } else {
                    Text("Connect")
                }
            }
            .buttonStyle(CLPrimaryButtonStyle(fillsWidth: false))
            .frame(minWidth: 96)
            .disabled(isConnecting)
            .accessibilityLabel("Connect with \(user.displayName)")
        }
        .clCardStyle()
    }
}

private struct IncomingRequestRowView: View {
    let item: ConnectRequestItem
    let isResponding: Bool
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: CLSpacing.sm) {
            HStack(spacing: CLSpacing.sm) {
                AvatarImageView(
                    localPreview: nil,
                    avatarBase64: item.peer.avatarBase64,
                    avatarURL: item.peer.avatarURL,
                    size: 52
                )

                VStack(alignment: .leading, spacing: CLSpacing.xxs) {
                    Text(item.peer.displayName)
                        .font(CLTypography.headline)
                        .foregroundStyle(CLColor.ink)

                    if !item.peer.interests.isEmpty {
                        Text(item.peer.interests.prefix(3).joined(separator: " · "))
                            .font(CLTypography.footnote)
                            .foregroundStyle(CLColor.inkMuted)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: CLSpacing.sm) {
                Button(action: onDecline) {
                    if isResponding {
                        ProgressView()
                            .tint(CLColor.ink)
                    } else {
                        Text("Decline")
                    }
                }
                .buttonStyle(CLSecondaryButtonStyle())
                .disabled(isResponding)
                .accessibilityLabel("Decline \(item.peer.displayName)")

                Button(action: onAccept) {
                    if isResponding {
                        ProgressView()
                            .tint(CLColor.onPrimary)
                    } else {
                        Text("Accept")
                    }
                }
                .buttonStyle(CLPrimaryButtonStyle())
                .disabled(isResponding)
                .accessibilityLabel("Accept \(item.peer.displayName)")
            }
        }
        .clCardStyle()
    }
}

private struct MatchedRowView: View {
    let item: MatchedConnectionItem
    let isOpening: Bool
    let onOpenChat: () -> Void

    var body: some View {
        HStack(spacing: CLSpacing.sm) {
            AvatarImageView(
                localPreview: nil,
                avatarBase64: item.peer.avatarBase64,
                avatarURL: item.peer.avatarURL,
                size: 52
            )

            VStack(alignment: .leading, spacing: CLSpacing.xxs) {
                Text(item.peer.displayName)
                    .font(CLTypography.headline)
                    .foregroundStyle(CLColor.ink)

                Text("Connected")
                    .font(CLTypography.footnote)
                    .foregroundStyle(CLColor.success)
            }

            Spacer(minLength: CLSpacing.xs)

            Button(action: onOpenChat) {
                if isOpening {
                    ProgressView()
                        .tint(CLColor.onPrimary)
                } else {
                    Text("Open Chat")
                }
            }
            .buttonStyle(CLPrimaryButtonStyle(fillsWidth: false))
            .frame(minWidth: 112)
            .disabled(isOpening)
            .accessibilityLabel("Open chat with \(item.peer.displayName)")
        }
        .clCardStyle()
    }
}
