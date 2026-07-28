import SwiftUI

/// One large Discover card + optional underlay. Swipe left = Pass, swipe right = View profile.
/// Reduce Motion: drag disabled; use buttons only.
struct ConnectDiscoverDeckView: View {
    let top: User
    let underlay: User?
    let onPass: () -> Void
    let onViewProfile: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var dragOffset: CGSize = .zero
    @State private var isExiting = false
    @State private var exitTask: Task<Void, Never>?

    private let swipeThreshold: CGFloat = 120

    var body: some View {
        VStack(spacing: CLSpacing.lg) {
            ZStack {
                if let underlay {
                    DiscoverCardView(user: underlay, isTop: false)
                        .scaleEffect(0.96)
                        .offset(y: 10)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }

                DiscoverCardView(user: top, isTop: true)
                    .offset(dragOffset)
                    .rotationEffect(.degrees(Double(dragOffset.width / 24)))
                    .opacity(isExiting ? 0 : 1)
                    .modifier(OptionalDragModifier(
                        isEnabled: !reduceMotion,
                        onChanged: { translation in
                            guard !isExiting else { return }
                            // Ignore vertical-dominant drags so parent ScrollView can scroll.
                            guard abs(translation.width) > abs(translation.height) else { return }
                            dragOffset = CGSize(width: translation.width, height: 0)
                        },
                        onEnded: { translation in
                            guard abs(translation.width) > abs(translation.height) else {
                                withAnimation(reduceMotion ? .easeOut(duration: 0.15) : CLMotion.soft) {
                                    dragOffset = .zero
                                }
                                return
                            }
                            handleDragEnded(CGSize(width: translation.width, height: 0))
                        }
                    ))
                    .clSoftSpring(value: dragOffset.width)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(accessibilitySummary(for: top))
                    .accessibilityHint("Swipe right or use View profile to open profile. Swipe left or use Pass to skip.")
                    .accessibilityAddTraits(.isButton)
                    .onTapGesture { onViewProfile() }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 360)

            HStack(spacing: CLSpacing.md) {
                Button {
                    animateExit(direction: -1, then: onPass)
                } label: {
                    Text("Pass")
                }
                .buttonStyle(CLSecondaryButtonStyle())
                .accessibilityLabel("Pass \(top.displayName)")

                Button {
                    onViewProfile()
                } label: {
                    Text("View profile")
                }
                .buttonStyle(CLPrimaryButtonStyle())
                .accessibilityLabel("View profile of \(top.displayName)")
            }
        }
        .onChange(of: top.id) { _ in
            exitTask?.cancel()
            exitTask = nil
            dragOffset = .zero
            isExiting = false
        }
        .onDisappear {
            exitTask?.cancel()
            exitTask = nil
        }
    }

    private func handleDragEnded(_ translation: CGSize) {
        guard !isExiting else { return }
        let dx = translation.width
        if dx <= -swipeThreshold {
            animateExit(direction: -1, then: onPass)
        } else if dx >= swipeThreshold {
            // Profile-first: open sheet, keep card (no Pass).
            withAnimation(reduceMotion ? .easeOut(duration: 0.15) : CLMotion.soft) {
                dragOffset = .zero
            }
            onViewProfile()
        } else {
            withAnimation(reduceMotion ? .easeOut(duration: 0.15) : CLMotion.soft) {
                dragOffset = .zero
            }
        }
    }

    private func animateExit(direction: CGFloat, then action: @escaping () -> Void) {
        guard !isExiting else { return }
        isExiting = true
        exitTask?.cancel()
        let travel = direction * 480
        withAnimation(reduceMotion ? .easeOut(duration: 0.18) : CLMotion.softLarge) {
            dragOffset = CGSize(width: travel, height: dragOffset.height * 0.4)
        }
        let delayNanos: UInt64 = reduceMotion ? 180_000_000 : 280_000_000
        exitTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: delayNanos)
            guard !Task.isCancelled else { return }
            action()
            dragOffset = .zero
            isExiting = false
            exitTask = nil
        }
    }

    private func accessibilitySummary(for user: User) -> String {
        let interests = user.interests.prefix(3).joined(separator: ", ")
        if interests.isEmpty {
            return user.displayName
        }
        return "\(user.displayName). Interests: \(interests)"
    }
}

// MARK: - Card

private struct DiscoverCardView: View {
    let user: User
    let isTop: Bool

    var body: some View {
        VStack(spacing: CLSpacing.md) {
            AvatarImageView(
                localPreview: nil,
                avatarBase64: user.avatarBase64,
                avatarURL: user.avatarURL,
                size: 140
            )
            .accessibilityHidden(true)

            Text(user.displayName.isEmpty ? "Member" : user.displayName)
                .font(CLTypography.title)
                .foregroundStyle(CLColor.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            if !user.interests.isEmpty {
                FlowLayout(spacing: CLSpacing.xs) {
                    ForEach(Array(user.interests.prefix(3)), id: \.self) { interest in
                        Text(interest)
                            .font(CLTypography.subheadline)
                            .foregroundStyle(CLColor.inkSecondary)
                            .padding(.horizontal, CLSpacing.sm)
                            .padding(.vertical, CLSpacing.xs)
                            .background(CLColor.primarySoft.opacity(0.65))
                            .clipShape(Capsule())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(CLSpacing.lg)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 320)
        .background(CLColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: CLRadius.lg, style: .continuous))
        .shadow(
            color: isTop ? CLShadow.cardColor : CLShadow.cardColor.opacity(0.5),
            radius: CLShadow.cardRadius,
            x: 0,
            y: CLShadow.cardY
        )
        .overlay(
            RoundedRectangle(cornerRadius: CLRadius.lg, style: .continuous)
                .stroke(CLColor.hairline, lineWidth: 1)
        )
    }
}

/// Attaches a drag gesture only when enabled (Reduce Motion → buttons only).
private struct OptionalDragModifier: ViewModifier {
    let isEnabled: Bool
    let onChanged: (CGSize) -> Void
    let onEnded: (CGSize) -> Void

    func body(content: Content) -> some View {
        if isEnabled {
            content.gesture(
                DragGesture()
                    .onChanged { value in onChanged(value.translation) }
                    .onEnded { value in onEnded(value.translation) }
            )
        } else {
            content
        }
    }
}
