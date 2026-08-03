import UIKit

/// Accessibility element that can run a custom activate handler (retry / avatar tap).
final class ActivatableAccessibilityElement: UIAccessibilityElement {
    var onActivate: (() -> Bool)?

    override func accessibilityActivate() -> Bool {
        if let onActivate {
            return onActivate()
        }
        return super.accessibilityActivate()
    }
}
