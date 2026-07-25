import SwiftUI

/// Connect discovery feed in Soft Orbit language. ViewModel bindings unchanged.
///
/// Data flow:
/// Appear / Refresh → ConnectViewModel.load → Community / Connection / User repos
///   → section states → UI
/// Select community / Connect / Accept / Decline / Open Chat → ViewModel → repos → state
struct ConnectView: View {
    @ObservedObject var viewModel: ConnectViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CLSpacing.lg) {
                    if let actionErrorMessage = viewModel.actionErrorMessage {
                        Text(actionErrorMessage)
                            .font(CLTypography.caption)
                            .foregroundStyle(CLColor.error)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(CLSpacing.md)
                            .background(CLColor.surfaceSoft)
                            .clipShape(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous))
                            .accessibilityLabel("Connect error: \(actionErrorMessage)")
                            .clAppear()
                    }

                    communityPickerSection
                        .clAppear()
                    candidatesSection
                        .clAppear(delay: 0.05)
                    incomingSection
                        .clAppear(delay: 0.08)
                    matchedSection
                        .clAppear(delay: 0.11)
                }
                .padding(CLSpacing.base)
            }
            .background(CLColor.canvas.ignoresSafeArea())
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
        VStack(alignment: .leading, spacing: CLSpacing.md) {
            sectionTitle("Community")

            switch viewModel.communitiesState {
            case .idle, .loading:
                ProgressView("Loading communities…")
                    .tint(CLColor.primary)
            case .empty:
                inlineEmpty(
                    systemImage: "circle.grid.cross",
                    title: "Join a circle first",
                    message: "Pick a community elsewhere, then come back to find people."
                )
            case let .error(message):
                sectionError(message) {
                    Task { await viewModel.load() }
                }
            case let .loaded(communities):
                let selectedName = selectedCommunityName(from: communities)
                Menu {
                    ForEach(communities) { community in
                        Button(community.name) {
                            Task { await viewModel.selectCommunity(community.id) }
                        }
                    }
                } label: {
                    HStack(spacing: CLSpacing.sm) {
                        Circle()
                            .fill(CLColor.companionSoft)
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle()
                                    .fill(CLColor.primary.opacity(0.85))
                                    .frame(width: 8, height: 8)
                                    .offset(x: 6, y: -4)
                            )
                            .accessibilityHidden(true)

                        Text(selectedName)
                            .font(CLTypography.bodyMedium)
                            .foregroundStyle(CLColor.ink)
                            .lineLimit(1)
                        Spacer(minLength: CLSpacing.sm)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(CLColor.muted)
                    }
                    .padding(.horizontal, CLSpacing.base)
                    .frame(minHeight: AccessibilityHelpers.minimumTouchTarget + 4)
                    .background(CLColor.surfaceSoft)
                    .clipShape(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous)
                            .strokeBorder(CLColor.hairline, lineWidth: 1)
                    )
                }
                .accessibilityLabel("Select community")
                .accessibilityValue(selectedName)
            }
        }
    }

    // MARK: - Candidates

    @ViewBuilder
    private var candidatesSection: some View {
        VStack(alignment: .leading, spacing: CLSpacing.md) {
            sectionTitle("People nearby")

            if viewModel.selectedCommunityId == nil {
                inlineEmpty(
                    systemImage: "person.2",
                    title: "Choose a community",
                    message: "Select a circle above to see people you can connect with."
                )
            } else {
                switch viewModel.candidatesState {
                case .idle, .loading:
                    ProgressView("Loading candidates…")
                        .tint(CLColor.primary)
                case .empty:
                    inlineEmpty(
                        systemImage: "sparkles",
                        title: "Quiet for now",
                        message: "No new people here yet. Pull to refresh, or try another circle."
                    )
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
            sectionTitle("Incoming requests")

            switch viewModel.incomingState {
            case .idle, .loading:
                ProgressView("Loading requests…")
                    .tint(CLColor.primary)
            case .empty:
                inlineEmpty(
                    systemImage: "envelope.open",
                    title: "No requests waiting",
                    message: "When someone wants to connect, they'll show up here."
                )
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
        VStack(alignment: .leading, spacing: CLSpacing.md) {
            sectionTitle("Matched")

            switch viewModel.matchedState {
            case .idle, .loading:
                ProgressView("Loading matches…")
                    .tint(CLColor.primary)
            case .empty:
                inlineEmpty(
                    systemImage: "heart.circle",
                    title: "Your matches land here",
                    message: "Accept a request — or get accepted — and start chatting."
                )
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

    // MARK: - Helpers

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(CLTypography.section)
            .foregroundStyle(CLColor.ink)
            .accessibilityAddTraits(.isHeader)
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
        .padding(CLSpacing.base)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clCardStyle()
    }

    private func inlineEmpty(systemImage: String, title: String, message: String) -> some View {
        HStack(alignment: .top, spacing: CLSpacing.md) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(CLColor.muted)
                .padding(CLSpacing.sm)
                .background(Circle().fill(CLColor.companionSoft))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: CLSpacing.xs) {
                Text(title)
                    .font(CLTypography.bodyMedium)
                    .foregroundStyle(CLColor.ink)
                Text(message)
                    .font(CLTypography.callout)
                    .foregroundStyle(CLColor.muted)
            }
        }
        .padding(CLSpacing.base)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clCardStyle()
    }
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
                size: 56
            )

            VStack(alignment: .leading, spacing: CLSpacing.xs) {
                Text(user.displayName)
                    .font(CLTypography.bodyMedium)
                    .foregroundStyle(CLColor.ink)
                    .lineLimit(1)

                if !user.interests.isEmpty {
                    interestMeta(user.interests)
                }
            }

            Spacer(minLength: CLSpacing.sm)

            Button(action: onConnect) {
                Group {
                    if isConnecting {
                        ProgressView()
                            .tint(CLColor.onPrimary)
                    } else {
                        Text("Connect")
                            .font(CLTypography.buttonSmall)
                    }
                }
                .padding(.horizontal, CLSpacing.md)
                .frame(minWidth: 88, minHeight: AccessibilityHelpers.minimumTouchTarget)
            }
            .foregroundStyle(CLColor.onPrimary)
            .background(CLColor.primary)
            .clipShape(RoundedRectangle(cornerRadius: CLRadius.sm, style: .continuous))
            .buttonStyle(.plain)
            .disabled(isConnecting)
            .accessibilityLabel("Connect with \(user.displayName)")
        }
        .padding(CLSpacing.md)
        .clCardStyle()
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
                    size: 56
                )

                VStack(alignment: .leading, spacing: CLSpacing.xs) {
                    Text(item.peer.displayName)
                        .font(CLTypography.bodyMedium)
                        .foregroundStyle(CLColor.ink)

                    if !item.peer.interests.isEmpty {
                        interestMeta(item.peer.interests)
                    }
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: CLSpacing.md) {
                Button(action: onDecline) {
                    if isResponding {
                        ProgressView()
                            .tint(CLColor.ink)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
                    } else {
                        Text("Decline")
                            .font(CLTypography.buttonSmall)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
                    }
                }
                .foregroundStyle(CLColor.ink)
                .background(CLColor.surfaceSoft)
                .clipShape(RoundedRectangle(cornerRadius: CLRadius.sm, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: CLRadius.sm, style: .continuous)
                        .strokeBorder(CLColor.hairline, lineWidth: 1)
                )
                .buttonStyle(.plain)
                .disabled(isResponding)
                .accessibilityLabel("Decline \(item.peer.displayName)")

                Button(action: onAccept) {
                    if isResponding {
                        ProgressView()
                            .tint(CLColor.onPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
                    } else {
                        Text("Accept")
                            .font(CLTypography.buttonSmall)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
                    }
                }
                .foregroundStyle(CLColor.onPrimary)
                .background(CLColor.primary)
                .clipShape(RoundedRectangle(cornerRadius: CLRadius.sm, style: .continuous))
                .buttonStyle(.plain)
                .disabled(isResponding)
                .accessibilityLabel("Accept \(item.peer.displayName)")
            }
        }
        .padding(CLSpacing.md)
        .clCardStyle()
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
                size: 56
            )

            VStack(alignment: .leading, spacing: CLSpacing.xs) {
                Text(item.peer.displayName)
                    .font(CLTypography.bodyMedium)
                    .foregroundStyle(CLColor.ink)

                CLMetaPill(title: "Connected", emphasizesBrand: false)
            }

            Spacer(minLength: CLSpacing.sm)

            Button(action: onOpenChat) {
                Group {
                    if isOpening {
                        ProgressView()
                            .tint(CLColor.onPrimary)
                    } else {
                        Text("Open Chat")
                            .font(CLTypography.buttonSmall)
                    }
                }
                .padding(.horizontal, CLSpacing.md)
                .frame(minWidth: 100, minHeight: AccessibilityHelpers.minimumTouchTarget)
            }
            .foregroundStyle(CLColor.onPrimary)
            .background(CLColor.primary)
            .clipShape(RoundedRectangle(cornerRadius: CLRadius.sm, style: .continuous))
            .buttonStyle(.plain)
            .disabled(isOpening)
            .accessibilityLabel("Open chat with \(item.peer.displayName)")
        }
        .padding(CLSpacing.md)
        .clCardStyle()
    }
}

// MARK: - Interest meta

@ViewBuilder
private func interestMeta(_ interests: [String]) -> some View {
    let shown = Array(interests.prefix(3).enumerated())
    HStack(spacing: CLSpacing.xs) {
        ForEach(shown, id: \.offset) { _, interest in
            CLMetaPill(title: interest)
                .lineLimit(1)
        }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(shown.map(\.element).joined(separator: ", "))
}
