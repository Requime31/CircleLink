import SwiftUI
import UIKit

/// A zero-chrome bridge that measures the actual UIKit target view. It never invents a frame.
struct CLUIKitGuideTargetBridge: UIViewRepresentable {
    let target: CLGuideTarget
    var instance: String?
    let resolveView: () -> UIView?
    let onFrameChange: (CLGuideTargetID, CGRect?) -> Void

    func makeUIView(context: Context) -> BridgeView {
        let view = BridgeView()
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ bridge: BridgeView, context: Context) {
        bridge.onLayout = {
            guard let targetView = resolveView(), targetView.window != nil,
                  !targetView.isHidden, targetView.alpha > 0.01 else {
                onFrameChange(.init(target, instance: instance), nil)
                return
            }
            CLGuideAccessibilityCoordinator.shared.registerUIKitTarget(
                id: .init(target, instance: instance), view: targetView
            )
            onFrameChange(
                .init(target, instance: instance),
                targetView.convert(targetView.bounds, to: bridge)
            )
        }
        bridge.setNeedsLayout()
    }

    final class BridgeView: UIView {
        var onLayout: (() -> Void)?
        override func layoutSubviews() { super.layoutSubviews(); onLayout?() }
    }
}
