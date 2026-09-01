import SwiftUI
import UIKit

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
    @State private var scrollOffset: CGFloat = 0
    @State private var didCrossSwipeThreshold = false

    private let swipeThreshold: CGFloat = 96
    private let expansionThreshold: CGFloat = 52
    private let revealDistance: CGFloat = 140
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

    private var expansionProgress: CGFloat {
        min(max(scrollOffset / revealDistance, 0), 1)
    }

    var body: some View {
        GeometryReader { geometry in
            let collapsedCardHeight = max(480, geometry.size.height - CLSpacing.lg)

            ScrollView {
                heroDeck(height: collapsedCardHeight)
                    .id(ScrollAnchor.hero)
                    .background {
                        GeometryReader { contentGeometry in
                            Color.clear.preference(
                                key: DiscoverScrollOffsetPreferenceKey.self,
                                value: contentGeometry.frame(in: .named("connectDiscoverScroll")).minY
                            )
                        }
                    }
                    .padding(.horizontal, CLSpacing.screenHorizontal)
                    .padding(.top, CLSpacing.sm)
                    .padding(.bottom, CLSpacing.xxl)
            }
            .id(top.id)
            .coordinateSpace(name: "connectDiscoverScroll")
            .scrollIndicators(.hidden)
            .onPreferenceChange(DiscoverScrollOffsetPreferenceKey.self) { minY in
                scrollOffset = max(0, CLSpacing.sm - minY)
            }
            .onChange(of: top.id) { _ in
                resetForNewTopCard()
            }
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

    private func heroDeck(height: CGFloat) -> some View {
        ZStack(alignment: .top) {
            if let following {
                DiscoverCardView(user: following, height: height)
                    .id(following.id)
                    .scaleEffect(0.92 + 0.04 * revealProgress - 0.02 * expansionProgress)
                    .offset(y: 28 - 14 * revealProgress - 10 * expansionProgress)
                    .opacity(1 - expansionProgress)
                    .accessibilityHidden(true)
            }

            if let next {
                DiscoverCardView(user: next, height: height)
                    .id(next.id)
                    .scaleEffect(0.96 + 0.04 * revealProgress - 0.02 * expansionProgress)
                    .offset(y: 14 * (1 - revealProgress) - 8 * expansionProgress)
                    .opacity(1 - expansionProgress)
                    .accessibilityHidden(true)
            }

            heroCard(height: height)
        }
        .frame(maxWidth: .infinity)
    }

    private func heroCard(height: CGFloat) -> some View {
        VStack(spacing: 0) {
            DiscoverCardHero(user: top, height: height)
                .overlay {
                    swipeActionIndicators
                }
                .overlay(alignment: .bottom) {
                    expansionHint
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(top.displayNameWithAge)
                .accessibilityHint(
                    "Swipe left to pass, swipe right to say hi, or swipe up for more profile info."
                )

            profileDetails
                .id(ScrollAnchor.details)
                .padding(CLSpacing.lg)
                .background(CLColor.surface)
        }
            .background(CLColor.surface)
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
            .id(top.id)
            .offset(x: dragOffsetX)
            .rotationEffect(.degrees(Double(min(max(dragOffsetX / 24, -8), 8))))
            .modifier(HorizontalDragModifier(
                isEnabled: !isExiting && scrollOffset < expansionThreshold,
                onChanged: { translation in
                    // Horizontal-only: ignore vertical-dominant moves so ScrollView can scroll.
                    guard abs(translation.width) >= abs(translation.height) else { return }
                    // Follow the finger with no animation — interrupting snap-back
                    // would recreate the "Invalid sample AnimatablePair" crash.
                    withoutAnimation {
                        dragOffsetX = translation.width
                    }
                    updateSwipeThresholdFeedback(for: translation.width)
                },
                onEnded: { translation, predictedTranslation in
                    handleDragEnded(translation, predictedTranslation: predictedTranslation)
                }
            ))
            .frame(maxWidth: .infinity)
    }

    private var swipeActionIndicators: some View {
        let progress = min(abs(dragOffsetX) / swipeThreshold, 1)
        let travel = 152 * progress

        return HStack {
            swipeActionIndicator(systemImage: "xmark", isPositive: false, progress: progress)
                .offset(x: -88 + travel)
                .opacity(dragOffsetX < 0 ? progress : 0)

            Spacer()

            swipeActionIndicator(systemImage: "checkmark", isPositive: true, progress: progress)
                .offset(x: 88 - travel)
                .opacity(dragOffsetX > 0 ? progress : 0)
        }
        .padding(.horizontal, CLSpacing.sm)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func swipeActionIndicator(
        systemImage: String,
        isPositive: Bool,
        progress: CGFloat
    ) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 30, weight: .bold))
            .foregroundStyle(isPositive ? CLColor.primary : CLColor.ink)
            .frame(width: 76, height: 76)
            .background(.ultraThinMaterial, in: Circle())
            .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 1))
            .scaleEffect(0.72 + 0.28 * progress)
    }

    private var expansionHint: some View {
        HStack(spacing: CLSpacing.xs) {
            Image(systemName: "chevron.up")
            Text("Swipe up for more")
        }
        .font(CLTypography.caption)
        .foregroundStyle(.white)
        .padding(.horizontal, CLSpacing.md)
        .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
        .background(.black.opacity(0.24), in: Capsule())
        .padding(.bottom, CLSpacing.sm)
        .opacity(1 - expansionProgress)
        .accessibilityHidden(expansionProgress > 0.5)
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

    private func handleDragEnded(_ translation: CGSize, predictedTranslation: CGSize) {
        guard !isExiting else { return }
        let dx = translation.width
        let dy = translation.height
        let projectedDX = dx + (predictedTranslation.width - dx) * 0.35
        didCrossSwipeThreshold = false

        // Vertical-dominant → treat as scroll, snap card back.
        guard abs(dx) >= abs(dy) else {
            snapCardBack()
            return
        }

        if dx <= -swipeThreshold || projectedDX <= -swipeThreshold * 1.15 {
            animateExit(direction: -1) { userId in
                onPass(userId)
                return true
            }
        } else if dx >= swipeThreshold || projectedDX >= swipeThreshold * 1.15 {
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
        withAnimation(.easeOut(duration: 0.12)) {
            dragOffsetX = 0
        }
    }

    private func updateSwipeThresholdFeedback(for offset: CGFloat) {
        let crossedThreshold = abs(offset) >= swipeThreshold
        guard crossedThreshold != didCrossSwipeThreshold else { return }
        didCrossSwipeThreshold = crossedThreshold
        guard crossedThreshold else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.8)
    }

    private func animateExit(direction: CGFloat, then action: @escaping (String) -> Bool) {
        guard !isExiting else { return }
        let outgoingUserId = top.id
        isExiting = true
        exitTask?.cancel()
        let travel = direction * 480
        let duration: Double = reduceMotion ? 0.16 : 0.22
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

    private func resetForNewTopCard() {
        exitTask?.cancel()
        exitTask = nil
        withoutAnimation {
            scrollOffset = 0
        }
        resetDragWithoutAnimation()
    }

    /// Offset + rotation are one AnimatablePair. Instant resets must not animate.
    private func resetDragWithoutAnimation() {
        withoutAnimation {
            dragOffsetX = 0
            isExiting = false
            didCrossSwipeThreshold = false
        }
    }

    private func withoutAnimation(_ updates: () -> Void) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction, updates)
    }
}

private enum ScrollAnchor: Hashable {
    case hero
    case details
}

private struct DiscoverScrollOffsetPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
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
    let height: CGFloat

    var body: some View {
        DiscoverCardHero(user: user, height: height)
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

private struct DiscoverCardHero: View {
    let user: User
    let height: CGFloat?

    init(user: User, height: CGFloat? = nil) {
        self.user = user
        self.height = height
    }

    @ViewBuilder
    var body: some View {
        if let height {
            heroContent
                .frame(maxWidth: .infinity)
                .frame(height: height)
        } else {
            heroContent
                .aspectRatio(4 / 5, contentMode: .fit)
        }
    }

    private var heroContent: some View {
        Rectangle()
            .fill(Color.clear)
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
                    .lineLimit(1)
                    .padding(CLSpacing.lg)
            }
    }
}

/// Horizontal-only pan. It fails before recognition for vertical movement so the
/// parent ScrollView remains the sole owner of vertical gestures on the card.
private struct HorizontalDragModifier: ViewModifier {
    let isEnabled: Bool
    let onChanged: (CGSize) -> Void
    let onEnded: (CGSize, CGSize) -> Void

    func body(content: Content) -> some View {
        if isEnabled {
            content.overlay {
                HorizontalPanGestureView(onChanged: onChanged, onEnded: onEnded)
                    .accessibilityHidden(true)
            }
        } else {
            content
        }
    }
}

private struct HorizontalPanGestureView: UIViewRepresentable {
    let onChanged: (CGSize) -> Void
    let onEnded: (CGSize, CGSize) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onChanged: onChanged, onEnded: onEnded)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        view.isOpaque = false

        let recognizer = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        recognizer.delegate = context.coordinator
        recognizer.cancelsTouchesInView = false
        view.addGestureRecognizer(recognizer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onChanged = onChanged
        context.coordinator.onEnded = onEnded
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onChanged: (CGSize) -> Void
        var onEnded: (CGSize, CGSize) -> Void

        init(
            onChanged: @escaping (CGSize) -> Void,
            onEnded: @escaping (CGSize, CGSize) -> Void
        ) {
            self.onChanged = onChanged
            self.onEnded = onEnded
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer,
                  let view = pan.view else { return false }
            let velocity = pan.velocity(in: view)
            return abs(velocity.x) > abs(velocity.y)
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
            guard let view = recognizer.view else { return }
            let translation = recognizer.translation(in: view)
            let size = CGSize(width: translation.x, height: translation.y)

            switch recognizer.state {
            case .changed:
                onChanged(size)
            case .ended, .cancelled:
                let velocity = recognizer.velocity(in: view)
                let predicted = CGSize(
                    width: translation.x + velocity.x * 0.18,
                    height: translation.y + velocity.y * 0.18
                )
                onEnded(size, predicted)
            default:
                break
            }
        }
    }
}
