import SwiftUI

/// Discover page for one candidate: hero card + profile sections in one ScrollView.
/// Horizontal swipe on the card = Pass / Say Hi. Vertical scroll = Interests / About / Communities.
struct ConnectDiscoverDeckView: View {
    let top: User
    let next: User?
    let following: User?
    let communities: [Community]
    let isSendingConnect: Bool
    let onPass: (String) -> Void
    let onSayHi: (String) -> Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var dragOffsetX: CGFloat = 0
    @State private var isExiting = false
    @State private var exitTask: Task<Void, Never>?

    private let swipeThreshold: CGFloat = 120
    private let visibleCommunityLimit = 3

    init(
        top: User,
        next: User?,
        following: User?,
        communities: [Community],
        isSendingConnect: Bool,
        onPass: @escaping (String) -> Void,
        onSayHi: @escaping (String) -> Bool
    ) {
        self.top = top
        self.next = next
        self.following = following
        self.communities = communities
        self.isSendingConnect = isSendingConnect
        self.onPass = onPass
        self.onSayHi = onSayHi
    }

    private var visibleCommunities: [Community] {
        Array(communities.prefix(visibleCommunityLimit))
    }

    private var overflowCommunityCount: Int {
        max(0, communities.count - visibleCommunityLimit)
    }

    private var revealProgress: CGFloat {
        min(abs(dragOffsetX) / swipeThreshold, 1)
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: CLSpacing.lg) {
                    heroDeck
                        .frame(minHeight: max(480, geometry.size.height - CLSpacing.lg))

                    profileDetails
                }
                .padding(.horizontal, CLSpacing.screenHorizontal)
                .padding(.top, CLSpacing.sm)
                .padding(.bottom, CLSpacing.xxl)
            }
            .scrollIndicators(.hidden)
        }
        .onChange(of: top.id) { _ in
            exitTask?.cancel()
            exitTask = nil
            resetDragWithoutAnimation()
        }
        .onDisappear {
            exitTask?.cancel()
            exitTask = nil
        }
        .task(id: preloadTaskID) {
            await preloadUpcomingImages()
        }
    }

    // MARK: - Hero

    private var heroDeck: some View {
        ZStack {
            if let following {
                DiscoverCardView(user: following)
                    .id(following.id)
                    .scaleEffect(0.92 + 0.04 * revealProgress)
                    .offset(y: 28 - 14 * revealProgress)
                    .accessibilityHidden(true)
            }

            if let next {
                DiscoverCardView(user: next)
                    .id(next.id)
                    .scaleEffect(0.96 + 0.04 * revealProgress)
                    .offset(y: 14 * (1 - revealProgress))
                    .accessibilityHidden(true)
            }

            heroCard
        }
        .frame(maxWidth: .infinity)
    }

    private var heroCard: some View {
        DiscoverCardView(user: top)
            .id(top.id)
            .offset(x: dragOffsetX)
            .rotationEffect(.degrees(Double(dragOffsetX / 24)))
            .modifier(HorizontalDragModifier(
                isEnabled: !isExiting,
                onChanged: { translation in
                    // Horizontal-only: ignore vertical-dominant moves so ScrollView can scroll.
                    guard abs(translation.width) >= abs(translation.height) else { return }
                    // Follow the finger with no animation — interrupting snap-back
                    // would recreate the "Invalid sample AnimatablePair" crash.
                    withoutAnimation {
                        dragOffsetX = translation.width
                    }
                },
                onEnded: { translation in
                    handleDragEnded(translation)
                }
            ))
            .accessibilityElement(children: .combine)
            .accessibilityLabel(top.displayNameWithAge)
            .accessibilityHint(
                "Swipe left to pass, swipe right to say hi, or scroll down for more profile info."
            )
            .frame(maxWidth: .infinity)
    }

    // MARK: - Profile details (same screen)

    private var profileDetails: some View {
        VStack(alignment: .leading, spacing: CLSpacing.lg) {
            if !top.interests.isEmpty {
                interestsSection(top.interests)
            }

            aboutSection(top.aboutMe)

            if !communities.isEmpty {
                communitiesSection
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(CLTypography.title)
            .foregroundStyle(CLColor.ink)
    }

    private func interestsSection(_ interests: [String]) -> some View {
        VStack(alignment: .leading, spacing: CLSpacing.sm) {
            sectionHeader("Interests")

            FlowLayout(spacing: CLSpacing.sm) {
                ForEach(interests, id: \.self) { interest in
                    CLChip(title: interest)
                }
            }
        }
    }

    private func aboutSection(_ aboutMe: String) -> some View {
        VStack(alignment: .leading, spacing: CLSpacing.sm) {
            sectionHeader("About")

            Text(aboutMe.isEmpty ? "No bio yet." : aboutMe)
                .font(CLTypography.callout)
                .foregroundStyle(aboutMe.isEmpty ? CLColor.inkMuted : CLColor.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(CLSpacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(CLColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: CLRadius.lg, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: CLRadius.lg, style: .continuous)
                        .stroke(CLColor.hairline, lineWidth: 1)
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var communitiesSection: some View {
        VStack(alignment: .leading, spacing: CLSpacing.sm) {
            sectionHeader("Communities")

            FlowLayout(spacing: CLSpacing.sm) {
                ForEach(visibleCommunities) { community in
                    CLChip(
                        title: CommunityContentPolicy.safeDisplayName(community.name, limit: 24),
                        accessibilityLabelText: CommunityContentPolicy.safeDisplayName(community.name)
                    )
                }

                if overflowCommunityCount > 0 {
                    CLChip(
                        title: "+\(overflowCommunityCount)",
                        isEmphasized: true,
                        accessibilityLabelText: "\(overflowCommunityCount) more communities"
                    )
                }
            }
        }
    }

    // MARK: - Drag

    private func handleDragEnded(_ translation: CGSize) {
        guard !isExiting else { return }
        let dx = translation.width
        let dy = translation.height

        // Vertical-dominant → treat as scroll, snap card back.
        guard abs(dx) >= abs(dy) else {
            snapCardBack()
            return
        }

        if dx <= -swipeThreshold {
            animateExit(direction: -1) { userId in
                onPass(userId)
                return true
            }
        } else if dx >= swipeThreshold {
            guard !isSendingConnect else {
                snapCardBack()
                return
            }
            animateExit(direction: 1, then: onSayHi)
        } else {
            snapCardBack()
        }
    }

    private func snapCardBack() {
        // Timed easeOut — never a spring on offset+rotation (same AnimatablePair crash).
        withAnimation(.easeOut(duration: 0.15)) {
            dragOffsetX = 0
        }
    }

    private func animateExit(direction: CGFloat, then action: @escaping (String) -> Bool) {
        guard !isExiting else { return }
        let outgoingUserId = top.id
        isExiting = true
        exitTask?.cancel()
        let travel = direction * 480
        let duration: Double = reduceMotion ? 0.18 : 0.28
        // Drop any in-flight snap-back first, then start a new timed animation.
        withoutAnimation {
            dragOffsetX = dragOffsetX
        }
        withAnimation(.easeOut(duration: duration)) {
            dragOffsetX = travel
        }
        exitTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            exitTask = nil
            if !action(outgoingUserId) {
                resetDragWithoutAnimation()
            }
        }
    }

    private var preloadTaskID: String {
        [next?.id, following?.id].compactMap { $0 }.joined(separator: "|")
    }

    private func preloadUpcomingImages() async {
        let urls = [next?.avatarURL, following?.avatarURL].compactMap { $0 }
        await withTaskGroup(of: Void.self) { group in
            for url in urls {
                group.addTask {
                    _ = try? await ImageLoader.shared.load(from: url)
                }
            }
        }
    }

    /// Offset + rotation are one AnimatablePair. Instant resets must not animate.
    private func resetDragWithoutAnimation() {
        withoutAnimation {
            dragOffsetX = 0
            isExiting = false
        }
    }

    private func withoutAnimation(_ updates: () -> Void) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction, updates)
    }
}

// MARK: - Press dim (no lift)

private struct DeckCircleButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed && isEnabled ? 0.92 : 1)
            .animation(
                reduceMotion ? .easeOut(duration: 0.15) : CLMotion.micro,
                value: configuration.isPressed
            )
    }
}

// MARK: - Card

private struct DiscoverCardView: View {
    let user: User

    var body: some View {
        Color.clear
            .aspectRatio(4 / 5, contentMode: .fit)
            .overlay {
                ProfileHeroImageView(
                    avatarBase64: user.avatarBase64,
                    avatarURL: user.avatarURL
                )
            }
            .overlay {
                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.55)],
                    startPoint: .center,
                    endPoint: .bottom
                )
            }
            .overlay(alignment: .bottomLeading) {
                Text(user.displayNameWithAge)
                    .font(CLTypography.title)
                    .foregroundStyle(.white)
                    .padding(CLSpacing.lg)
            }
            .clipShape(RoundedRectangle(cornerRadius: CLRadius.xl, style: .continuous))
            .shadow(
                color: CLShadow.cardColor,
                radius: CLShadow.cardRadius,
                x: 0,
                y: CLShadow.cardY
            )
            .overlay(
                RoundedRectangle(cornerRadius: CLRadius.xl, style: .continuous)
                    .stroke(CLColor.hairline, lineWidth: 1)
            )
    }
}

/// Horizontal-only drag. Vertical moves are ignored so parent ScrollView can scroll.
private struct HorizontalDragModifier: ViewModifier {
    let isEnabled: Bool
    let onChanged: (CGSize) -> Void
    let onEnded: (CGSize) -> Void

    func body(content: Content) -> some View {
        if isEnabled {
            content.highPriorityGesture(
                DragGesture(minimumDistance: 16)
                    .onChanged { value in
                        // Only claim the gesture once it's clearly horizontal.
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        onChanged(value.translation)
                    }
                    .onEnded { value in onEnded(value.translation) }
            )
        } else {
            content
        }
    }
}
