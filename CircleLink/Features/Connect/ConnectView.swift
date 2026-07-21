import SwiftUI

struct ConnectView: View {
    @ObservedObject var viewModel: ConnectViewModel

    private let brand = Color(red: 1.0, green: 0.22, blue: 0.36)
    private let ink = Color(red: 0.133, green: 0.133, blue: 0.133)
    private let muted = Color(red: 0.416, green: 0.416, blue: 0.416)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    if let actionErrorMessage = viewModel.actionErrorMessage {
                        Text(actionErrorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityLabel("Connect error: \(actionErrorMessage)")
                    }

                    communityPickerSection
                    candidatesSection
                    incomingSection
                    matchedSection
                }
                .padding(16)
            }
            .background(Color.white)
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
        VStack(alignment: .leading, spacing: 12) {
            Text("Community")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(ink)

            switch viewModel.communitiesState {
            case .idle, .loading:
                ProgressView("Loading communities…")
            case .empty:
                Text("Join a community first to find people.")
                    .font(.subheadline)
                    .foregroundStyle(muted)
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
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(ink)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(muted)
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 48)
                    .background(Color(red: 0.969, green: 0.969, blue: 0.969))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .accessibilityLabel("Select community")
            }
        }
    }

    // MARK: - Candidates

    @ViewBuilder
    private var candidatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("People nearby")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(ink)

            if viewModel.selectedCommunityId == nil {
                Text("Select a community to see candidates.")
                    .font(.subheadline)
                    .foregroundStyle(muted)
            } else {
                switch viewModel.candidatesState {
                case .idle, .loading:
                    ProgressView("Loading candidates…")
                case .empty:
                    Text("No new people to connect with here.")
                        .font(.subheadline)
                        .foregroundStyle(muted)
                case let .error(message):
                    sectionError(message) {
                        if let communityId = viewModel.selectedCommunityId {
                            Task { await viewModel.selectCommunity(communityId) }
                        }
                    }
                case let .loaded(candidates):
                    LazyVStack(spacing: 12) {
                        ForEach(candidates) { user in
                            CandidateRowView(
                                user: user,
                                isConnecting: viewModel.connectingUserId == user.id,
                                brand: brand,
                                ink: ink,
                                muted: muted
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
        VStack(alignment: .leading, spacing: 12) {
            Text("Incoming requests")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(ink)

            switch viewModel.incomingState {
            case .idle, .loading:
                ProgressView("Loading requests…")
            case .empty:
                Text("No pending requests.")
                    .font(.subheadline)
                    .foregroundStyle(muted)
            case let .error(message):
                sectionError(message) {
                    Task { await viewModel.load() }
                }
            case let .loaded(items):
                LazyVStack(spacing: 12) {
                    ForEach(items) { item in
                        IncomingRequestRowView(
                            item: item,
                            isResponding: viewModel.respondingRequestId == item.id,
                            brand: brand,
                            ink: ink,
                            muted: muted,
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
        VStack(alignment: .leading, spacing: 12) {
            Text("Matched")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(ink)

            switch viewModel.matchedState {
            case .idle, .loading:
                ProgressView("Loading matches…")
            case .empty:
                Text("Accepted connections will show here.")
                    .font(.subheadline)
                    .foregroundStyle(muted)
            case let .error(message):
                sectionError(message) {
                    Task { await viewModel.load() }
                }
            case let .loaded(items):
                LazyVStack(spacing: 12) {
                    ForEach(items) { item in
                        MatchedRowView(
                            item: item,
                            isOpening: viewModel.openingChatPeerId == item.peer.id,
                            brand: brand,
                            ink: ink,
                            muted: muted
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
        VStack(alignment: .leading, spacing: 8) {
            Text(message)
                .font(.subheadline)
                .foregroundStyle(muted)
                .accessibilityLabel("Error: \(message)")
            Button("Retry", action: retry)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(brand)
                .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
                .accessibilityLabel("Retry loading section")
        }
    }
}

// MARK: - Rows

private struct CandidateRowView: View {
    let user: User
    let isConnecting: Bool
    let brand: Color
    let ink: Color
    let muted: Color
    let onConnect: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            AvatarImageView(
                localPreview: nil,
                avatarBase64: user.avatarBase64,
                avatarURL: user.avatarURL,
                size: 52
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(ink)
                    .lineLimit(1)

                if !user.interests.isEmpty {
                    Text(user.interests.prefix(3).joined(separator: " · "))
                        .font(.system(size: 13))
                        .foregroundStyle(muted)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            Button(action: onConnect) {
                if isConnecting {
                    ProgressView()
                        .frame(width: 88, height: AccessibilityHelpers.minimumTouchTarget)
                } else {
                    Text("Connect")
                        .font(.subheadline.weight(.medium))
                        .frame(width: 88, height: AccessibilityHelpers.minimumTouchTarget)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(brand)
            .disabled(isConnecting)
            .accessibilityLabel("Connect with \(user.displayName)")
        }
        .padding(12)
        .background(Color(red: 0.969, green: 0.969, blue: 0.969))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct IncomingRequestRowView: View {
    let item: ConnectRequestItem
    let isResponding: Bool
    let brand: Color
    let ink: Color
    let muted: Color
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                AvatarImageView(
                    localPreview: nil,
                    avatarBase64: item.peer.avatarBase64,
                    avatarURL: item.peer.avatarURL,
                    size: 52
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.peer.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(ink)

                    if !item.peer.interests.isEmpty {
                        Text(item.peer.interests.prefix(3).joined(separator: " · "))
                            .font(.system(size: 13))
                            .foregroundStyle(muted)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 12) {
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
                .tint(brand)
                .disabled(isResponding)
                .accessibilityLabel("Accept \(item.peer.displayName)")
            }
        }
        .padding(12)
        .background(Color(red: 0.969, green: 0.969, blue: 0.969))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct MatchedRowView: View {
    let item: MatchedConnectionItem
    let isOpening: Bool
    let brand: Color
    let ink: Color
    let muted: Color
    let onOpenChat: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            AvatarImageView(
                localPreview: nil,
                avatarBase64: item.peer.avatarBase64,
                avatarURL: item.peer.avatarURL,
                size: 52
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(item.peer.displayName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(ink)

                Text("Connected")
                    .font(.system(size: 13))
                    .foregroundStyle(muted)
            }

            Spacer(minLength: 8)

            Button(action: onOpenChat) {
                if isOpening {
                    ProgressView()
                        .frame(width: 100, height: AccessibilityHelpers.minimumTouchTarget)
                } else {
                    Text("Open Chat")
                        .font(.subheadline.weight(.medium))
                        .frame(width: 100, height: AccessibilityHelpers.minimumTouchTarget)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(brand)
            .disabled(isOpening)
            .accessibilityLabel("Open chat with \(item.peer.displayName)")
        }
        .padding(12)
        .background(Color(red: 0.969, green: 0.969, blue: 0.969))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
