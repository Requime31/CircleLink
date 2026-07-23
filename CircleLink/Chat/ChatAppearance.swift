import UIKit

/// UIKit chat visual tokens — aligned with DESIGN.md / `CLColor` (SwiftUI).
/// Only appearance; no messaging logic lives here.
enum ChatAppearance {
    static let primary = UIColor(red: 1.0, green: 0.22, blue: 0.36, alpha: 1.0)
    static let ink = UIColor(red: 0.133, green: 0.133, blue: 0.133, alpha: 1.0)
    static let muted = UIColor(red: 0.416, green: 0.416, blue: 0.416, alpha: 1.0)
    static let canvas = UIColor.white
    static let surfaceSoft = UIColor(red: 0.969, green: 0.969, blue: 0.969, alpha: 1.0)
    static let hairline = UIColor(red: 0.867, green: 0.867, blue: 0.867, alpha: 1.0)
    /// Incoming bubble ≈ surface-strong `#f2f2f2`.
    static let incomingBubble = UIColor(red: 0.949, green: 0.949, blue: 0.949, alpha: 1.0)
    static let outgoingBubble = primary
    static let onPrimary = UIColor.white

    static var bodyFont: UIFont { .preferredFont(forTextStyle: .body) }
    static var captionFont: UIFont { .preferredFont(forTextStyle: .caption1) }
    static var titleFont: UIFont { .preferredFont(forTextStyle: .headline) }

    enum Spacing {
        static let bubbleVertical: CGFloat = 4
        static let bubbleHorizontalInset: CGFloat = 16
        static let bubbleOppositeInset: CGFloat = 64
        static let bubblePaddingH: CGFloat = 12
        static let bubblePaddingV: CGFloat = 8
        static let timestampGap: CGFloat = 4
        static let statusGap: CGFloat = 8
        static let barEdge: CGFloat = 8
        static let fieldMinHeight: CGFloat = 36
        static let barMinHeight: CGFloat = 56
        static let imageHeight: CGFloat = 180
    }

    enum Radius {
        static let bubble: CGFloat = 16
        static let image: CGFloat = 12
        static let field: CGFloat = 8
    }
}
