import UIKit

@MainActor
final class CLGuideAccessibilityCoordinator {
    static let shared = CLGuideAccessibilityCoordinator()
    private var swiftUITargets: [CLGuideTargetID: (token: UUID, restore: () -> Void)] = [:]
    private var UIKitTargets: [CLGuideTargetID: WeakView] = [:]
    private var activeTargetID: CLGuideTargetID?

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
    func prepareTarget(id: CLGuideTargetID) { activeTargetID = id }

    func focusTip(_ focus: @escaping () -> Void) {
        DispatchQueue.main.async {
            focus()
            UIAccessibility.post(notification: .screenChanged, argument: nil)
        }
    }

    func restoreTargetFocus() {
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
