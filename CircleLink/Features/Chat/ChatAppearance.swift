import UIKit

/// UIKit aliases for the shared semantic palette plus Chat-specific geometry and typography.
enum ChatAppearance {
    // MARK: Surfaces

    static let canvas = CLUIColor.canvas
    static let surface = CLUIColor.surface
    static let surfaceSoft = CLUIColor.surfaceSoft
    static let hairline = CLUIColor.hairline
    static let hairlineStrong = CLUIColor.hairlineStrong

    // MARK: Ink

    static let ink = CLUIColor.ink
    static let inkSecondary = CLUIColor.inkSecondary
    static let inkMuted = CLUIColor.inkMuted
    static let inkDisabled = CLUIColor.inkDisabled

    // MARK: Primary (Sunset Clay)

    static let primary = CLUIColor.primary
    static let primaryPressed = CLUIColor.primaryPressed
    static let primarySoft = CLUIColor.primarySoft
    static let onPrimaryStrong = CLUIColor.onPrimaryStrong

    // MARK: Bubbles

    /// Mine: soft clay + dark ink
    static let outgoingBubble = primarySoft
    /// Theirs: muted parchment group (DESIGN.md)
    static let incomingBubble = surfaceSoft

    // MARK: Geometry (single source of truth)

    static let bubbleRadius: CGFloat = 18
    static let bubbleTailRadius: CGFloat = 12
    static let bubbleImageRadius: CGFloat = 14
    static let fieldRadius: CGFloat = 14

    static let bubblePaddingH: CGFloat = 14
    static let bubblePaddingV: CGFloat = 10
    static let timestampSpacing: CGFloat = 4
    static let statusGap: CGFloat = 8
    static let sideGutter: CGFloat = 16
    static let oppositeGutter: CGFloat = 64

    /// Gap between consecutive bubbles from the same sender (DESIGN.md).
    static let sameSenderGap: CGFloat = 4
    /// Gap between different senders / thread edges (DESIGN.md).
    static let differentSenderGap: CGFloat = 16

    /// Fixed media width so image-only bubbles don’t collapse to the timestamp width.
    static let bubbleImageWidth: CGFloat = 220
    static let bubbleImageHeight: CGFloat = 180

    static let barEdge: CGFloat = 8
    static let barMinHeight: CGFloat = 56

    // MARK: Typography (Dynamic Type)

    static var bodyFont: UIFont { .preferredFont(forTextStyle: .body) }
    static var captionFont: UIFont { .preferredFont(forTextStyle: .caption1) }
    static var titleFont: UIFont { .preferredFont(forTextStyle: .headline) }
}
