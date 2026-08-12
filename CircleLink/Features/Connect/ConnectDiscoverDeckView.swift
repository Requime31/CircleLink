import SwiftUI

/// Discover page for one candidate: hero card + profile sections in one ScrollView.
/// Horizontal swipe on the card = Pass / Say Hi. Vertical scroll = Interests / About / Communities.
/// Reduce Motion: drag disabled; use buttons only.
struct ConnectDiscoverDeckView: View {
    let top: User
    let communities: [Community]
    let canUndo: Bool
    let isSendingConnect: Bool
    let onPass: () -> Void
    let onSayHi: () -> Void
    let onUndo: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var dragOffsetX: CGFloat = 0
    @State private var isExiting = false
    @State private var exitTask: Task<Void, Never>?

    private let swipeThreshold: CGFloat = 120
    private let visibleCommunityLimit = 3

    private var visibleCommunities: [Community] {
        Array(communities.prefix(visibleCommunityLimit))
    }

    private var overflowCommunityCount: Int {
        max(0, communities.count - visibleCommunityLimit)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CLSpacing.lg) {
                heroCard

                profileDetails
            }
            .padding(.horizontal, CLSpacing.screenHorizontal)
            .padding(.top, CLSpacing.sm)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            actionBar
        }
        .onChange(of: top.id) { _ in
            exitTask?.cancel()
            exitTask = nil
            dragOffsetX = 0
            isExiting = false
        }
        .onDisappear {
            exitTask?.cancel()
            exitTask = nil
        }
    }

    // MARK: - Hero

    private var heroCard: some View {
        DiscoverCardView(user: top)
            .offset(x: dragOffsetX)
            .rotationEffect(.degrees(Double(dragOffsetX / 24)))
            .modifier(HorizontalDragModifier(
                isEnabled: !reduceMotion && !isExiting,
                onChanged: { translation in
                    // Horizontal-only: ignore vertical-dominant moves so ScrollView can scroll.
                    guard abs(translation.width) >= abs(translation.height) else { return }
                    dragOffsetX = translation.width
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
                    CLChip(title: community.name)
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

    // MARK: - Actions

    private var actionBar: some View {
        HStack(spacing: CLSpacing.lg) {
            deckCircleButton(
                systemImage: "xmark",
                title: "Pass",
                isEmphasis: false,
                size: 64
            ) {
                animateExit(direction: -1, then: onPass)
            }
            .accessibilityLabel("Pass \(top.displayName)")

            deckCircleButton(
                systemImage: "heart.fill",
                title: "Say Hi",
                isEmphasis: true,
                size: 72
            ) {
                guard !isSendingConnect else { return }
                animateExit(direction: 1, then: onSayHi)
            }
            .disabled(isSendingConnect)
            .accessibilityLabel("Say Hi to \(top.displayName)")

            deckCircleButton(
                systemImage: "arrow.counterclockwise",
                title: "Back",
                isEmphasis: false,
                size: 64
            ) {
                onUndo()
            }
            .opacity(canUndo ? 1 : 0.35)
            .disabled(!canUndo)
            .accessibilityLabel("Undo last pass")
        }
        .padding(.vertical, CLSpacing.md)
        .frame(maxWidth: .infinity)
        .background(CLColor.canvas)
    }

    private func deckCircleButton(
        systemImage: String,
        title: String,
        isEmphasis: Bool,
        size: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: CLSpacing.xs) {
                ZStack {
                    if isSendingConnect && isEmphasis {
                        ProgressView()
                            .tint(CLColor.onPrimaryStrong)
                    } else {
                        Image(systemName: systemImage)
                            .font(.system(size: size * 0.3, weight: .semibold))
                            .foregroundStyle(isEmphasis ? CLColor.onPrimaryStrong : CLColor.ink)
                    }
                }
                .frame(width: size, height: size)
                .background(isEmphasis ? CLColor.primary : CLColor.surface)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(CLColor.hairline, lineWidth: isEmphasis ? 0 : 1)
                )

                Text(title)
                    .font(CLTypography.caption)
                    .foregroundStyle(isEmphasis ? CLColor.primary : CLColor.inkSecondary)
            }
        }
        .buttonStyle(DeckCircleButtonStyle())
    }

    // MARK: - Drag

    private func handleDragEnded(_ translation: CGSize) {
        guard !isExiting else { return }
        let dx = translation.width
        let dy = translation.height

        // Vertical-dominant → treat as scroll, snap card back.
        guard abs(dx) >= abs(dy) else {
            withAnimation(reduceMotion ? .easeOut(duration: 0.15) : CLMotion.soft) {
                dragOffsetX = 0
            }
            return
        }

        if dx <= -swipeThreshold {
            animateExit(direction: -1, then: onPass)
        } else if dx >= swipeThreshold {
            guard !isSendingConnect else {
                withAnimation(reduceMotion ? .easeOut(duration: 0.15) : CLMotion.soft) {
                    dragOffsetX = 0
                }
                return
            }
            animateExit(direction: 1, then: onSayHi)
        } else {
            withAnimation(reduceMotion ? .easeOut(duration: 0.15) : CLMotion.soft) {
                dragOffsetX = 0
            }
        }
    }

    private func animateExit(direction: CGFloat, then action: @escaping () -> Void) {
        guard !isExiting else { return }
        isExiting = true
        exitTask?.cancel()
        let travel = direction * 480
        withAnimation(reduceMotion ? .easeOut(duration: 0.18) : CLMotion.softLarge) {
            dragOffsetX = travel
        }
        let delayNanos: UInt64 = reduceMotion ? 180_000_000 : 280_000_000
        exitTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: delayNanos)
            guard !Task.isCancelled else { return }
            // Reset drag first, then swap candidate — avoids blank flash.
            dragOffsetX = 0
            isExiting = false
            exitTask = nil
            action()
        }
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
