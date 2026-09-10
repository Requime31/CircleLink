import SwiftUI
import UIKit

private struct CLGuideManagerKey: EnvironmentKey {
    static let defaultValue: ContextualGuideManager? = nil
}

private extension EnvironmentValues {
    var contextualGuideManager: ContextualGuideManager? {
        get { self[CLGuideManagerKey.self] }
        set { self[CLGuideManagerKey.self] = newValue }
    }
}

struct CLGuideTargetAnchor {
    let id: CLGuideTargetID
    let bounds: Anchor<CGRect>
    var clippingBounds: [Anchor<CGRect>] = []
}

private struct CLGuideTargetPreferenceKey: PreferenceKey {
    static var defaultValue: [CLGuideTargetAnchor] = []
    static func reduce(value: inout [CLGuideTargetAnchor], nextValue: () -> [CLGuideTargetAnchor]) {
        value.append(contentsOf: nextValue())
    }
}

private struct CLGuideBlockerPreferenceKey: PreferenceKey {
    static var defaultValue = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) { value = value || nextValue() }
}

extension View {
    func clGuideTarget(_ target: CLGuideTarget, instance: String? = nil, enabled: Bool = true) -> some View {
        modifier(CLGuideTargetModifier(id: .init(target, instance: instance), enabled: enabled))
    }

    /// Apply inside a navigation destination, so UIKit appearance tracks that screen.
    func clGuideScreen(_ series: CLGuideSeries) -> some View {
        modifier(CLGuideScreenModifier(series: series))
    }

    func clGuideViewport() -> some View {
        transformAnchorPreference(key: CLGuideTargetPreferenceKey.self, value: .bounds) { targets, bounds in
            for index in targets.indices { targets[index].clippingBounds.append(bounds) }
        }
    }

    func clGuidePresentationBlocked(_ blocked: Bool) -> some View {
        preference(key: CLGuideBlockerPreferenceKey.self, value: blocked)
    }
}


private struct CLGuideScreenModifier: ViewModifier {
    let series: CLGuideSeries
    @Environment(\.contextualGuideManager) private var manager
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .clGuideViewport()
            .transformPreference(CLGuideTargetPreferenceKey.self) { targets in
                if !appeared { targets = [] }
            }
            .background(CLGuideAppearanceObserver { visible in
                appeared = visible
                if visible { manager?.visit(series) }
                else { manager?.invalidatePresentation() }
            })
    }
}

/// A child controller receives the enclosing navigation/tab appearance callbacks.
private struct CLGuideAppearanceObserver: UIViewControllerRepresentable {
    let onChange: (Bool) -> Void

    func makeUIViewController(context: Context) -> Observer {
        let controller = Observer()
        controller.onChange = onChange
        return controller
    }

    func updateUIViewController(_ controller: Observer, context: Context) {
        controller.onChange = onChange
    }

    final class Observer: UIViewController {
        var onChange: ((Bool) -> Void)?
        private var revision = 0

        override func loadView() {
            view = UIView()
            view.isUserInteractionEnabled = false
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            report(true)
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            report(false)
        }

        private func report(_ visible: Bool) {
            revision += 1
            let expected = revision
            // Appearance can be delivered while SwiftUI is updating the hierarchy.
            DispatchQueue.main.async { [weak self] in
                guard let self, self.revision == expected else { return }
                self.onChange?(visible)
            }
        }
    }
}

private struct CLGuideResolvedTarget: Equatable {
    let id: CLGuideTargetID
    let frame: CGRect
}

private struct CLGuideLayoutSnapshot: Equatable {
    let targets: [CLGuideResolvedTarget]
    let safeBounds: CGRect
    let generation: Int
    let blocked: Bool
}

private struct CLGuideTargetModifier: ViewModifier {
    let id: CLGuideTargetID
    let enabled: Bool
    @AccessibilityFocusState private var focused: Bool
    @State private var registrationToken: UUID?

    func body(content: Content) -> some View {
        content
            .accessibilityFocused($focused)
            .anchorPreference(key: CLGuideTargetPreferenceKey.self, value: .bounds) {
                enabled ? [CLGuideTargetAnchor(id: id, bounds: $0)] : []
            }
            .onAppear {
                registrationToken = CLGuideAccessibilityCoordinator.shared.registerSwiftUITarget(id: id) {
                    focused = true
                }
            }
            .onDisappear {
                if let registrationToken {
                    CLGuideAccessibilityCoordinator.shared.unregisterSwiftUITarget(
                        id: id, token: registrationToken
                    )
                }
            }
    }
}

struct CLGuideHost<Content: View>: View {
    @ObservedObject private var manager: ContextualGuideManager
    private let content: Content
    private let customDismiss: ((CLGuideTip) -> Bool)?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var settledSnapshot: CLGuideLayoutSnapshot?
    @State private var keyboardVisible = false
    @State private var descendantPresentationBlocked = false

    init(
        manager: ContextualGuideManager,
        customDismiss: ((CLGuideTip) -> Bool)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.manager = manager
        self.customDismiss = customDismiss
        self.content = content()
    }

    var body: some View {
        content
            .accessibilityHidden(manager.activeTip != nil)
            .environment(\.contextualGuideManager, manager)
            .overlayPreferenceValue(CLGuideTargetPreferenceKey.self) { anchors in
                GeometryReader { proxy in
                    let viewport = CGRect(origin: .zero, size: proxy.size)
                    let safeBounds = CGRect(
                        x: viewport.minX + proxy.safeAreaInsets.leading,
                        y: viewport.minY + proxy.safeAreaInsets.top,
                        width: viewport.width - proxy.safeAreaInsets.leading - proxy.safeAreaInsets.trailing,
                        height: viewport.height - proxy.safeAreaInsets.top - proxy.safeAreaInsets.bottom
                    )
                    let targets = anchors.compactMap { anchor -> (CLGuideTargetID, CGRect)? in
                        let bounds = anchor.clippingBounds.reduce(safeBounds) { $0.intersection(proxy[$1]) }
                        guard let frame = CLGuidePlacementEngine.visibleIntersection(
                            target: proxy[anchor.bounds], viewport: bounds
                        ) else { return nil }
                        return (anchor.id, frame)
                    }
                    let eligibleTargets = targets.filter { id, _ in
                        switch manager.mode {
                        case .automatic: return id.instance != "manual"
                        case .manual: return id.instance == "manual"
                        }
                    }
                    let selected = selectedTarget(
                        for: manager.activeTip, targets: eligibleTargets, viewport: viewport
                    )

                    let snapshot = CLGuideLayoutSnapshot(
                        targets: eligibleTargets.map { CLGuideResolvedTarget(id: $0.0, frame: $0.1) },
                        safeBounds: safeBounds, generation: manager.presentationGeneration,
                        blocked: manager.isBlocked
                    )
                    ZStack {
                        CLGuideOverlay(
                            tip: settledSnapshot == snapshot ? manager.activeTip : nil,
                            targetID: selected?.0,
                            target: selected?.1,
                            viewport: viewport,
                            safeBounds: safeBounds,
                            reduceMotion: reduceMotion,
                            onDismiss: {
                                guard let tip = manager.activeTip else { return }
                                if customDismiss?(tip) != true { manager.dismissCurrent() }
                            }
                        )
                        .id("\(manager.activeTip?.id ?? "none")-\(selected?.0.target.rawValue ?? "none")-\(selected?.0.instance ?? "default")")
                    }
                    .task(id: snapshot) {
                        settledSnapshot = nil
                        manager.updateAvailableTargets([])
                        guard !snapshot.blocked else { return }
                        do {
                            // Restart whenever identity, bounds, appearance, or blockers change.
                            try await Task.sleep(nanoseconds: 300_000_000)
                            try Task.checkCancellation()
                            guard snapshot.generation == manager.presentationGeneration else { return }
                            settledSnapshot = snapshot
                            manager.updateAvailableTargets(
                                Set(snapshot.targets.map { $0.id.target }), generation: snapshot.generation
                            )
                        } catch is CancellationError {
                            return
                        } catch {
                            return
                        }
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                keyboardVisible = true
                updateBlocker()
            }
            .onPreferenceChange(CLGuideBlockerPreferenceKey.self) {
                let blocked = $0
                DispatchQueue.main.async {
                    descendantPresentationBlocked = blocked
                    updateBlocker()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidHideNotification)) { _ in
                keyboardVisible = false
                updateBlocker()
            }
            .onAppear { updateBlocker() }
            .onChange(of: scenePhase) { _ in updateBlocker() }
    }

    private func updateBlocker() {
        manager.updateBlocked(keyboardVisible || descendantPresentationBlocked || scenePhase != .active)
    }

    private func selectedTarget(
        for tip: CLGuideTip?, targets: [(CLGuideTargetID, CGRect)], viewport: CGRect
    ) -> (CLGuideTargetID, CGRect)? {
        guard let tip else { return nil }
        return targets
            .filter { $0.0.target == tip.target }
            .compactMap { id, frame -> (CLGuideTargetID, CGRect, CGFloat)? in
                guard let visible = CLGuidePlacementEngine.visibleIntersection(target: frame, viewport: viewport) else {
                    return nil
                }
                let distance = abs(visible.midX - viewport.midX) + abs(visible.midY - viewport.midY)
                return (id, visible, distance)
            }
            .min {
                if $0.2 != $1.2 { return $0.2 < $1.2 }
                return ($0.0.instance ?? "") < ($1.0.instance ?? "")
            }
            .map { ($0.0, $0.1) }
    }
}

struct CLGuideOverlay: View {
    let tip: CLGuideTip?
    let targetID: CLGuideTargetID?
    let target: CGRect?
    let viewport: CGRect
    let safeBounds: CGRect
    let reduceMotion: Bool
    let onDismiss: () -> Void
    @State private var tooltipSize = CGSize.zero
    @AccessibilityFocusState private var tipFocused: Bool

    var body: some View {
        if let tip, let targetID, let target {
            let width = min(340, max(0, safeBounds.width - 2 * max(16, CLSpacing.md)))
            let placement = CLGuidePlacementEngine.place(.init(
                target: target, viewport: viewport, safeBounds: safeBounds,
                tooltipSize: CGSize(width: width, height: tooltipSize.height), spacing: CLSpacing.md
            ))
            ZStack(alignment: .topLeading) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {}
                    .accessibilityHidden(true)
                if abs(tooltipSize.width - width) < 0.5, tooltipSize.height > 0 {
                    if tip.target == .connectCard {
                        Rectangle()
                            .fill(CLColor.guideScrim)
                            .frame(width: viewport.width, height: viewport.height)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    } else {
                        CLGuideDimmer(target: target)
                            .frame(width: viewport.width, height: viewport.height)
                            .allowsHitTesting(false)
                        CLGuideSpotlight(target: target)
                            .allowsHitTesting(false)
                    }
                    CLGuideTooltip(tip: tip, placement: placement, onDismiss: onDismiss)
                        .accessibilityFocused($tipFocused)
                        .onAppear {
                            CLGuideAccessibilityCoordinator.shared.prepareTarget(id: targetID)
                            CLGuideAccessibilityCoordinator.shared.focusTip { tipFocused = true }
                        }
                        .onDisappear {
                            CLGuideAccessibilityCoordinator.shared.cancelPendingFocus(for: targetID)
                        }
                }
            }
            .frame(width: viewport.width, height: viewport.height)
            .background(alignment: .topLeading) {
                // Measurement must not participate in the overlay's layout: accessibility
                // text can be taller than the entire viewport.
                CLGuideTooltipContent(tip: tip, onDismiss: onDismiss)
                    .frame(width: width)
                    .fixedSize(horizontal: false, vertical: true)
                    .readGuideSize($tooltipSize)
                    .hidden()
                    .accessibilityHidden(true)
            }
            .clipped()
            .transition(.opacity)
            .animation(reduceMotion ? nil : CLMotion.micro, value: tip.id)
        }
    }
}

struct CLGuideDimmer: View {
    let target: CGRect
    var body: some View {
        Rectangle()
            .fill(CLColor.guideScrim)
            .mask {
                Rectangle()
                    .overlay {
                        RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous)
                            .frame(width: target.width + CLSpacing.sm, height: target.height + CLSpacing.sm)
                            .position(x: target.midX, y: target.midY)
                            .blendMode(.destinationOut)
                    }
                    .compositingGroup()
            }
            .accessibilityHidden(true)
    }
}

struct CLGuideSpotlight: View {
    let target: CGRect
    var body: some View {
        RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous)
            .stroke(CLColor.primary, lineWidth: 2)
            .frame(width: target.width + CLSpacing.sm, height: target.height + CLSpacing.sm)
            .position(x: target.midX, y: target.midY)
            .accessibilityHidden(true)
    }
}

struct CLGuideTooltip: View {
    let tip: CLGuideTip
    let placement: CLGuidePlacement
    let onDismiss: () -> Void

    var body: some View {
        Group {
            if case let .bottomPanel(frame) = placement {
                ScrollView { CLGuideTooltipContent(tip: tip, onDismiss: onDismiss) }
                    .frame(height: frame.height)
            } else {
                CLGuideTooltipContent(tip: tip, onDismiss: onDismiss)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(width: placement.frame.width, height: placement.frame.height)
        .background(CLColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: CLRadius.lg, style: .continuous))
        .clFloatingShadow()
        .frame(width: placement.frame.width)
        .overlay { arrow }
        .position(x: placement.frame.midX, y: placement.frame.midY)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }

    @ViewBuilder private var arrow: some View {
        if case let .tooltip(frame, edge, offset) = placement {
            CLGuideArrow(edge: edge)
                .fill(CLColor.surface)
                .frame(width: 20, height: 10)
                .offset(
                    x: offset - frame.width / 2,
                    y: edge == .top ? -frame.height / 2 - 5 : frame.height / 2 + 5
                )
                .accessibilityHidden(true)
        }
    }
}

private struct CLGuideTooltipContent: View {
    let tip: CLGuideTip
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: CLSpacing.sm) {
            Text(tip.title).font(CLTypography.headline).foregroundStyle(CLColor.ink)
            Text(tip.message).font(CLTypography.body).foregroundStyle(CLColor.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(tip.target == .connectCard ? "Show me" : "Got it") {
                CLGuideAccessibilityCoordinator.shared.restoreTargetFocus()
                onDismiss()
            }
                .buttonStyle(CLPrimaryButtonStyle())
                .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
        }
        .padding(CLSpacing.md)
    }

}

extension CLGuidePlacement {
    fileprivate var frame: CGRect {
        switch self { case let .tooltip(frame, _, _), let .bottomPanel(frame): return frame }
    }
}

struct CLGuideArrow: Shape {
    let edge: CLGuideArrowEdge
    func path(in rect: CGRect) -> Path {
        var path = Path()
        if edge == .top {
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        } else {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        }
        path.closeSubpath()
        return path
    }
}

struct CLGuideSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next.width > 0, next.height > 0 { value = next }
    }
}

private extension View {
    func readGuideSize(_ size: Binding<CGSize>) -> some View {
        background(GeometryReader { proxy in
            Color.clear.preference(key: CLGuideSizeKey.self, value: proxy.size)
        })
        .onPreferenceChange(CLGuideSizeKey.self) { if $0 != .zero { size.wrappedValue = $0 } }
    }
}
