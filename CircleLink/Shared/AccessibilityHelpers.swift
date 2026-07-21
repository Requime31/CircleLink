import SwiftUI
import UIKit

/// Shared accessibility constants and helpers for CircleLink screens.
enum AccessibilityHelpers {
    /// Apple HIG minimum touch target size.
    static let minimumTouchTarget: CGFloat = 44

    /// Applies a minimum 44×44 pt hit area around a control without changing its visual size.
    static func expandTouchTarget(of view: UIView, size: CGFloat = minimumTouchTarget) {
        view.heightAnchor.constraint(greaterThanOrEqualToConstant: size).isActive = true
        view.widthAnchor.constraint(greaterThanOrEqualToConstant: size).isActive = true
    }
}

extension View {
    /// Ensures interactive controls meet the 44pt minimum touch target.
    func accessibilityMinTouchTarget(_ size: CGFloat = AccessibilityHelpers.minimumTouchTarget) -> some View {
        frame(minWidth: size, minHeight: size)
            .contentShape(Rectangle())
    }
}
