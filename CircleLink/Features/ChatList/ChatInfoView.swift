import SwiftUI

/// Destinations pushed from Chat Info one at a time (buttons + `navigationDestination`).
private enum ChatInfoDestination: Hashable {
    case search
    case participants
    case media
}

private enum ChatInfoAlert: Identifiable {
    case leave
    case clearHistory
    case hide
    case delete
    case leaveError(String)
    case actionError(String)

    var id: String {
        switch self {
        case .leave: return "leave"
        case .clearHistory: return "clearHistory"
        case .hide: return "hide"
        case .delete: return "delete"
        case .leaveError: return "leaveError"
        case .actionError: return "actionError"
        }
    }
}

/// Chat Info — mute, search, participants, media, clear history; leave (group) or hide/delete (DM).
struct ChatInfoView: View {
    @StateObject private var viewModel: ChatInfoViewModel
    let makePeerProfileSheet: (String, PeerProfileMode) -> PeerProfileSheet
    /// Called after leave / hide / delete so the list can refresh and pop.
    let onLeftChat: () -> Void
    /// Search hit → pop Info and open that message in the thread.
    let onOpenMessage: (Message) -> Void

    @State private var destination: ChatInfoDestination?
    @State private var activeAlert: ChatInfoAlert?
    @State private var presentedMedia: IdentifiedURL?

    init(
        viewModel: @autoclosure @escaping () -> ChatInfoViewModel,
        makePeerProfileSheet: @escaping (String, PeerProfileMode) -> PeerProfileSheet,
        onLeftChat: @escaping () -> Void,
        onOpenMessage: @escaping (Message) -> Void
    ) {
        _viewModel = StateObject(wrappedValue: viewModel())
        self.makePeerProfileSheet = makePeerProfileSheet
        self.onLeftChat = onLeftChat
        self.onOpenMessage = onOpenMessage
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                ProgressView("Loading…")
                    .tint(CLColor.primary)
                    .foregroundStyle(CLColor.inkMuted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .empty:
                emptyState(message: "Chat info unavailable.")
            case let .error(message):
                errorState(message: message)
            case let .loaded(info):
                infoContent(info)
            }
        }
        .clCanvasBackground()
        .navigationTitle(viewModel.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(
            isPresented: Binding(
                get: { destination != nil },
                set: { if !$0 { destination = nil } }
            )
        ) {
            if let route = destination {
                chatInfoDestination(route)
            }
        }
        .task {
            viewModel.load()
        }
        .onDisappear {
            viewModel.cancelLoad()
        }
        .onChange(of: viewModel.leaveErrorMessage) { message in
            if let message {
                activeAlert = .leaveError(message)
            }
        }
        .onChange(of: viewModel.actionErrorMessage) { message in
            if let message {
                activeAlert = .actionError(message)
            }
        }
        .alert(
            alertTitle,
            isPresented: Binding(
                get: { activeAlert != nil },
                set: { if !$0 { dismissAlert() } }
            ),
            presenting: activeAlert
        ) { alert in
            alertButtons(for: alert)
        } message: { alert in
            Text(alertMessage(for: alert))
        }
        .fullScreenCover(item: $presentedMedia) { item in
            ChatMediaFullscreenView(url: item.url)
        }
    }

    /// Pushes Search / Participants / Media on the parent `NavigationStack` (iOS 16+).
    /// Prefer this over deprecated `NavigationLink(destination:tag:selection:)`.
    @ViewBuilder
    private func chatInfoDestination(_ route: ChatInfoDestination) -> some View {
        switch route {
        case .search:
            ChatMessageSearchView(
                chatId: viewModel.chatId,
                chatRepository: viewModel.chatRepository
            ) { message in
                destination = nil
                onOpenMessage(message)
            }
        case .participants:
            if case let .loaded(info) = viewModel.state {
                ChatParticipantsView(
                    info: info,
                    currentUserId: viewModel.currentUserId,
                    makePeerProfileSheet: makePeerProfileSheet
                )
            } else {
                ProgressView()
                    .tint(CLColor.primary)
            }
        case .media:
            ChatMediaGalleryView(
                chatId: viewModel.chatId,
                chatRepository: viewModel.chatRepository
            )
        }
    }

    private var alertTitle: String {
        switch activeAlert {
        case .leave: return "Leave this chat?"
        case .clearHistory: return "Clear chat history?"
        case .hide: return "Hide this chat?"
        case .delete: return "Delete this chat?"
        case .leaveError: return "Couldn’t leave chat"
        case .actionError: return "Something went wrong"
        case .none: return ""
        }
    }

    private func alertMessage(for alert: ChatInfoAlert) -> String {
        switch alert {
        case .leave:
            return "You leave the chat only. You stay in the community."
        case .clearHistory:
            return "Messages stay for others. Only you stop seeing past messages."
        case .hide:
            return "The chat moves to Hidden. You can restore it later."
        case .delete:
            return "Removes the chat from your list. It can come back if they message you again."
        case let .leaveError(message), let .actionError(message):
            return message
        }
    }

    @ViewBuilder
    private func alertButtons(for alert: ChatInfoAlert) -> some View {
        switch alert {
        case .leave:
            Button("Leave Chat", role: .destructive) {
                Task { await confirmLeave() }
            }
            Button("Cancel", role: .cancel) {}
        case .clearHistory:
            Button("Clear History", role: .destructive) {
                Task { _ = await viewModel.clearHistory() }
            }
            Button("Cancel", role: .cancel) {}
        case .hide:
            Button("Hide", role: .destructive) {
                Task { await confirmHide() }
            }
            Button("Cancel", role: .cancel) {}
        case .delete:
            Button("Delete Chat", role: .destructive) {
                Task { await confirmDelete() }
            }
            Button("Cancel", role: .cancel) {}
        case .leaveError:
            Button("OK", role: .cancel) {
                viewModel.clearLeaveError()
            }
        case .actionError:
            Button("OK", role: .cancel) {
                viewModel.clearActionError()
            }
        }
    }

    private func dismissAlert() {
        if case .leaveError = activeAlert {
            viewModel.clearLeaveError()
        }
        if case .actionError = activeAlert {
            viewModel.clearActionError()
        }
        activeAlert = nil
    }

    @ViewBuilder
    private func infoContent(_ info: ChatInfo) -> some View {
        List {
            Section {
                header(for: info)
                    .listRowBackground(CLColor.canvas)
                    .listRowSeparator(.hidden)
            }

            Section {
                actionGrid(info)
                    .listRowBackground(CLColor.canvas)
                    .listRowSeparator(.hidden)
                    .listRowInsets(chatInfoCustomRowInsets(
                        top: CLSpacing.xs,
                        bottom: CLSpacing.sm
                    ))
            }

            Section {
                muteRow(info)

                Button {
                    destination = .participants
                } label: {
                    settingsLabel(systemImage: "person.2", title: "View Participants", showsChevron: true)
                }
                .buttonStyle(.plain)
                .listRowBackground(CLColor.surface)

                Button {
                    activeAlert = .clearHistory
                } label: {
                    settingsLabel(systemImage: "clock.arrow.circlepath", title: "Clear History", showsChevron: false)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isMutatingPrefs)
                .listRowBackground(CLColor.surface)
            }

            // insetGrouped already matches the settings-card width for this section.
            // Do NOT add screenHorizontal again — that made Shared Media narrower than the buttons.
            Section {
                mediaSection()
                    .listRowBackground(CLColor.canvas)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(
                        top: CLSpacing.sm,
                        leading: 0,
                        bottom: CLSpacing.sm,
                        trailing: 0
                    ))
            }

            Section {
                dangerZone(info)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .clAppear()
    }

    private func header(for info: ChatInfo) -> some View {
        let peer = viewModel.displayParticipants(from: info).first
        let count = info.participants.count

        return VStack(spacing: CLSpacing.sm) {
            if info.type == .direct, let peer {
                AvatarImageView(
                    localPreview: nil,
                    avatarBase64: peer.avatarBase64,
                    avatarURL: peer.avatarURL,
                    size: 96,
                    clip: .chat
                )
            } else {
                // Chats avatars = circle (DESIGN.md §0), including group placeholder.
                Image(systemName: "person.3.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(CLColor.inkSecondary)
                    .frame(width: 96, height: 96)
                    .background(Circle().fill(CLColor.surfaceSoft))
                    .clipShape(Circle())
                    .accessibilityHidden(true)
            }

            Text(info.title)
                .font(CLTypography.display)
                .foregroundStyle(CLColor.ink)
                .multilineTextAlignment(.center)

            Text(info.type == .group ? "\(count) Participants" : "Direct chat")
                .font(CLTypography.footnote)
                .foregroundStyle(CLColor.inkSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, CLSpacing.sm)
    }

    private func actionGrid(_ info: ChatInfo) -> some View {
        HStack(spacing: CLSpacing.sm) {
            actionTile(
                systemImage: info.isMuted ? "bell.slash.fill" : "bell.fill",
                title: info.isMuted ? "Unmute" : "Mute"
            ) {
                Task { await viewModel.setMuted(!info.isMuted) }
            }

            actionTile(systemImage: "magnifyingglass", title: "Search") {
                destination = .search
            }

            actionTile(systemImage: "person.2.fill", title: "People") {
                destination = .participants
            }
        }
    }

    private func actionTile(
        systemImage: String,
        title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: CLSpacing.xs) {
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(CLColor.primary)
                Text(title)
                    .font(CLTypography.footnote)
                    .foregroundStyle(CLColor.ink)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, CLSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous)
                    .fill(CLColor.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous)
                            .stroke(CLColor.hairline, lineWidth: 1)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func muteRow(_ info: ChatInfo) -> some View {
        Button {
            Task { await viewModel.setMuted(!info.isMuted) }
        } label: {
            HStack {
                settingsLabel(
                    systemImage: "bell.slash",
                    title: "Mute Notifications",
                    showsChevron: false
                )
                Spacer()
                Text(info.isMuted ? "On" : "Off")
                    .font(CLTypography.footnote)
                    .foregroundStyle(CLColor.inkSecondary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CLColor.inkMuted)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(info.isMuted ? "On" : "Off")
        .listRowBackground(CLColor.surface)
    }

    private func settingsLabel(
        systemImage: String,
        title: String,
        showsChevron: Bool
    ) -> some View {
        HStack(spacing: CLSpacing.md) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(CLColor.inkSecondary)
                .frame(width: 28, alignment: .center)
            Text(title)
                .font(CLTypography.body)
                .foregroundStyle(CLColor.ink)
            Spacer(minLength: 0)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CLColor.inkMuted)
            }
        }
    }

    /// Same horizontal inset as Mute / Search / People — keeps Shared Media edges aligned.
    private func chatInfoCustomRowInsets(top: CGFloat, bottom: CGFloat) -> EdgeInsets {
        EdgeInsets(
            top: top,
            leading: CLSpacing.screenHorizontal,
            bottom: bottom,
            trailing: CLSpacing.screenHorizontal
        )
    }

    private func mediaSection() -> some View {
        VStack(alignment: .leading, spacing: CLSpacing.sm) {
            HStack {
                Text("Shared Media")
                    .font(CLTypography.caption)
                    .foregroundStyle(CLColor.inkSecondary)
                    .textCase(.uppercase)
                Spacer(minLength: 0)
                Button("See All") {
                    destination = .media
                }
                .font(CLTypography.footnote.weight(.semibold))
                .foregroundStyle(CLColor.primary)
                .buttonStyle(.plain)
            }

            if viewModel.mediaPreview.isEmpty {
                Text("No photos yet.")
                    .font(CLTypography.subheadline)
                    .foregroundStyle(CLColor.inkMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, CLSpacing.xs)
            } else {
                // Equal flexible tiles. Color.clear owns size so AsyncImage cannot stretch the row.
                // Avoid LazyVGrid inside List — it often overlaps on iOS 16.
                // Buttons must also expand — otherwise the HStack shrink-wraps and List centers it
                // (looks more inset than Mute / Search / People).
                HStack(spacing: CLSpacing.xs) {
                    ForEach(viewModel.mediaPreview.prefix(4)) { message in
                        Button {
                            if let url = message.imageURL {
                                presentedMedia = IdentifiedURL(url)
                            } else {
                                destination = .media
                            }
                        } label: {
                            mediaThumbnail(for: message)
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("Open photo")
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func mediaThumbnail(for message: Message) -> some View {
        let shape = RoundedRectangle(cornerRadius: CLRadius.sm, style: .continuous)
        return Color.clear
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay {
                if let url = message.imageURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case let .success(image):
                            image
                                .resizable()
                                .scaledToFill()
                        default:
                            CLColor.surfaceSoft
                        }
                    }
                } else {
                    CLColor.surfaceSoft
                }
            }
            .clipped()
            .clipShape(shape)
            .overlay(shape.stroke(CLColor.hairline, lineWidth: 1))
    }

    @ViewBuilder
    private func dangerZone(_ info: ChatInfo) -> some View {
        if info.type == .group {
            Button(role: .destructive) {
                activeAlert = .leave
            } label: {
                HStack {
                    Spacer()
                    if viewModel.isLeaving {
                        ProgressView()
                            .tint(CLColor.error)
                    } else {
                        Text("Leave Chat")
                            .font(CLTypography.button)
                    }
                    Spacer()
                }
            }
            .disabled(viewModel.isLeaving)
            .accessibilityLabel("Leave chat")
            .listRowBackground(CLColor.surface)
        } else {
            Button {
                activeAlert = .hide
            } label: {
                settingsLabel(systemImage: "eye.slash", title: "Hide Chat", showsChevron: true)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isMutatingPrefs)
            .listRowBackground(CLColor.surface)

            Button(role: .destructive) {
                activeAlert = .delete
            } label: {
                HStack {
                    Spacer()
                    Text("Delete Chat")
                        .font(CLTypography.button)
                    Spacer()
                }
            }
            .disabled(viewModel.isMutatingPrefs)
            .listRowBackground(CLColor.surface)
        }
    }

    private func emptyState(message: String) -> some View {
        Text(message)
            .font(CLTypography.body)
            .foregroundStyle(CLColor.inkSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: CLSpacing.sm) {
            Text(message)
                .font(CLTypography.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(CLColor.inkSecondary)
            Button("Retry") {
                viewModel.load()
            }
            .buttonStyle(CLSecondaryButtonStyle())
        }
        .padding(CLSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func confirmLeave() async {
        let success = await viewModel.leaveChat()
        if success {
            onLeftChat()
        }
    }

    private func confirmHide() async {
        let success = await viewModel.hideChat()
        if success {
            onLeftChat()
        }
    }

    private func confirmDelete() async {
        let success = await viewModel.deleteDirectChat()
        if success {
            onLeftChat()
        }
    }
}
