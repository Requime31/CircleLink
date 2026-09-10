import UIKit

@MainActor
final class CLGuideAccessibilityCoordinator {
    static let shared = CLGuideAccessibilityCoordinator()
    private var swiftUITargets: [CLGuideTargetID: (token: UUID, restore: () -> Void)] = [:]
    private var UIKitTargets: [CLGuideTargetID: WeakView] = [:]
    private var activeTargetID: CLGuideTargetID?
    private var focusRevision = 0

    func registerSwiftUITarget(id: CLGuideTargetID, restore: @escaping () -> Void) -> UUID {
        let token = UUID()
        swiftUITargets[id] = (token, restore)
        return token
    }
    func unregisterSwiftUITarget(id: CLGuideTargetID, token: UUID) {
        guard swiftUITargets[id]?.token == token else { return }
        swiftUITargets[id] = nil
    }
    func registerUIKitTarget(id: CLGuideTargetID, view: UIView) { UIKitTargets[id] = WeakView(view) }
    func prepareTarget(id: CLGuideTargetID) {
        focusRevision += 1
        activeTargetID = id
    }

    func cancelPendingFocus(for id: CLGuideTargetID) {
        guard activeTargetID == id else { return }
        focusRevision += 1
    }

    func focusTip(_ focus: @escaping () -> Void) {
        let expected = focusRevision
        DispatchQueue.main.async { [weak self] in
            guard self?.focusRevision == expected else { return }
            focus()
            UIAccessibility.post(notification: .screenChanged, argument: nil)
        }
    }

    func restoreTargetFocus() {
        focusRevision += 1
        guard let activeTargetID else { return }
        if let view = UIKitTargets[activeTargetID]?.view {
            UIAccessibility.post(notification: .layoutChanged, argument: view)
        } else {
            swiftUITargets[activeTargetID]?.restore()
        }
    }
}

private final class WeakView {
    weak var view: UIView?
    init(_ view: UIView) { self.view = view }
}
