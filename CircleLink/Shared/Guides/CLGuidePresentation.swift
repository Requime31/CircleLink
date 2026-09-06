import SwiftUI
import UIKit

private let clGuideCoordinateSpace = "CircleLink.GuideHost"

struct CLGuideTargetAnchor {
    let id: CLGuideTargetID
    let bounds: Anchor<CGRect>
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
    func clGuideTarget(_ target: CLGuideTarget, instance: String? = nil) -> some View {
        modifier(CLGuideTargetModifier(id: .init(target, instance: instance)))
    }

    func clGuidePresentationBlocked(_ blocked: Bool) -> some View {
        preference(key: CLGuideBlockerPreferenceKey.self, value: blocked)
    }
}

private struct CLGuideTargetModifier: ViewModifier {
    let id: CLGuideTargetID
    @AccessibilityFocusState private var focused: Bool
    @State private var registrationToken: UUID?

    func body(content: Content) -> some View {
        content
            .accessibilityFocused($focused)
            .anchorPreference(key: CLGuideTargetPreferenceKey.self, value: .bounds) {
                [CLGuideTargetAnchor(id: id, bounds: $0)]
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
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var keyboardVisible = false
    @State private var descendantPresentationBlocked = false

    init(manager: ContextualGuideManager, @ViewBuilder content: () -> Content) {
        self.manager = manager
        self.content = content()
    }

    var body: some View {
        content
            .accessibilityHidden(manager.activeTip != nil)
            .coordinateSpace(name: clGuideCoordinateSpace)
            .overlayPreferenceValue(CLGuideTargetPreferenceKey.self) { anchors in
                GeometryReader { proxy in
                    let viewport = proxy.frame(in: .named(clGuideCoordinateSpace))
                    let safeBounds = CGRect(
                        x: viewport.minX + proxy.safeAreaInsets.leading,
                        y: viewport.minY + proxy.safeAreaInsets.top,
                        width: viewport.width - proxy.safeAreaInsets.leading - proxy.safeAreaInsets.trailing,
                        height: viewport.height - proxy.safeAreaInsets.top - proxy.safeAreaInsets.bottom
                    )
                    let targets = anchors.map { ($0.id, proxy[$0.bounds]) }
                    let eligibleTargets = targets.filter { id, _ in
                        switch manager.mode {
                        case .automatic: return id.instance != "manual"
                        case .manual: return id.instance == "manual"
                        }
                    }
                    let selected = selectedTarget(
                        for: manager.activeTip, targets: eligibleTargets, viewport: viewport
                    )

                    CLGuideOverlay(
                        tip: manager.activeTip,
                        targetID: selected?.0,
                        target: selected?.1,
                        viewport: viewport,
                        safeBounds: safeBounds,
                        reduceMotion: reduceMotion,
                        onDismiss: manager.dismissCurrent
                    )
                    .id("\(manager.activeTip?.id ?? "none")-\(selected?.0.target.rawValue ?? "none")-\(selected?.0.instance ?? "default")")
                    .onAppear {
                        let value = targetKinds(eligibleTargets, viewport: viewport)
                        DispatchQueue.main.async { manager.updateAvailableTargets(value) }
                    }
                    .onChange(of: targetKinds(eligibleTargets, viewport: viewport)) { value in
                        DispatchQueue.main.async { manager.updateAvailableTargets(value) }
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
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                keyboardVisible = false
                updateBlocker()
            }
            .onAppear { updateBlocker() }
            .onChange(of: scenePhase) { _ in updateBlocker() }
    }

    private func updateBlocker() {
        manager.updateBlocked(keyboardVisible || descendantPresentationBlocked || scenePhase != .active)
    }

    private func targetKinds(_ targets: [(CLGuideTargetID, CGRect)], viewport: CGRect) -> Set<CLGuideTarget> {
        Set(targets.compactMap { id, frame in
            CLGuidePlacementEngine.visibleIntersection(target: frame, viewport: viewport) == nil ? nil : id.target
        })
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

private struct CLGuideOverlay: View {
    let tip: CLGuideTip?
    let targetID: CLGuideTargetID?
    let target: CGRect?
    let viewport: CGRect
    let safeBounds: CGRect
    let reduceMotion: Bool
    let onDismiss: () -> Void
    @State private var tooltipSize = CGSize(width: 300, height: 160)
    @AccessibilityFocusState private var tipFocused: Bool

    var body: some View {
        if let tip, let targetID, let target {
            let placement = CLGuidePlacementEngine.place(.init(
                target: target, viewport: viewport, safeBounds: safeBounds,
                tooltipSize: tooltipSize, spacing: CLSpacing.md
            ))
            ZStack(alignment: .topLeading) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {}
                    .accessibilityHidden(true)
                CLGuideDimmer(target: target)
                    .frame(width: viewport.width, height: viewport.height)
                    .allowsHitTesting(false)
                CLGuideSpotlight(target: target)
                    .allowsHitTesting(false)
                CLGuideTooltip(tip: tip, placement: placement, onDismiss: onDismiss)
                    .readGuideSize($tooltipSize)
                    .accessibilityFocused($tipFocused)
            }
            .transition(.opacity)
            .animation(reduceMotion ? nil : CLMotion.micro, value: tip.id)
            .onAppear {
                CLGuideAccessibilityCoordinator.shared.prepareTarget(id: targetID)
                CLGuideAccessibilityCoordinator.shared.focusTip { tipFocused = true }
            }
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
                ScrollView { tooltipContent }
                    .frame(height: frame.height)
            } else {
                tooltipContent
            }
        }
        .background(CLColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: CLRadius.lg, style: .continuous))
        .clFloatingShadow()
        .frame(width: placement.frame.width)
        .position(x: placement.frame.midX, y: placement.frame.midY)
        .overlay { arrow }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }

    private var tooltipContent: some View {
        VStack(alignment: .leading, spacing: CLSpacing.sm) {
            Text(tip.title).font(CLTypography.headline).foregroundStyle(CLColor.ink)
            Text(tip.message).font(CLTypography.body).foregroundStyle(CLColor.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Got it") {
                onDismiss()
                CLGuideAccessibilityCoordinator.shared.restoreTargetFocus()
            }
                .buttonStyle(CLPrimaryButtonStyle())
                .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
        }
        .padding(CLSpacing.md)
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

private struct CLGuideSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
}

private extension View {
    func readGuideSize(_ size: Binding<CGSize>) -> some View {
        background(GeometryReader { proxy in
            Color.clear.preference(key: CLGuideSizeKey.self, value: proxy.size)
        })
        .onPreferenceChange(CLGuideSizeKey.self) { if $0 != .zero { size.wrappedValue = $0 } }
    }
}
