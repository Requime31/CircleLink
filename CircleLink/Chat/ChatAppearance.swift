import UIKit

/// UIKit tokens for Chat — mirrors `CLColor` / DESIGN.md hex.
/// Visual chrome only; keep Dynamic Type fonts. Chat stays UIKit-isolated.
enum ChatAppearance {
    // MARK: Surfaces

    /// `#FAF9F7`
    static let canvas = UIColor(red: 0.980, green: 0.976, blue: 0.969, alpha: 1.0)
    /// `#FFFFFF`
    static let surface = UIColor.white
    /// `#F5F3F0`
    static let surfaceSoft = UIColor(red: 0.961, green: 0.953, blue: 0.941, alpha: 1.0)
    /// `#E8E4DF`
    static let hairline = UIColor(red: 0.910, green: 0.894, blue: 0.875, alpha: 1.0)
    /// `#D4CFC8`
    static let hairlineStrong = UIColor(red: 0.831, green: 0.812, blue: 0.784, alpha: 1.0)

    // MARK: Ink

    /// `#1A1A1A`
    static let ink = UIColor(red: 0.102, green: 0.102, blue: 0.102, alpha: 1.0)
    /// `#5C574F`
    static let inkSecondary = UIColor(red: 0.361, green: 0.341, blue: 0.310, alpha: 1.0)
    /// `#8A847A`
    static let inkMuted = UIColor(red: 0.541, green: 0.518, blue: 0.478, alpha: 1.0)
    /// `#B8B2A8`
    static let inkDisabled = UIColor(red: 0.722, green: 0.698, blue: 0.659, alpha: 1.0)

    // MARK: Primary (peach)

    /// `#F2A68A`
    static let primary = UIColor(red: 0.949, green: 0.651, blue: 0.541, alpha: 1.0)
    /// `#E08B6C`
    static let primaryPressed = UIColor(red: 0.878, green: 0.545, blue: 0.424, alpha: 1.0)
    /// `#FDE8DE`
    static let primarySoft = UIColor(red: 0.992, green: 0.910, blue: 0.871, alpha: 1.0)

    // MARK: Bubbles

    /// Mine: soft peach + dark ink
    static let outgoingBubble = primarySoft
    /// Theirs: white surface on warm canvas
    static let incomingBubble = surface

    // MARK: Geometry

    static let bubbleRadius: CGFloat = 18
    static let bubbleTailRadius: CGFloat = 12
    static let bubbleImageRadius: CGFloat = 14
    static let fieldRadius: CGFloat = 14

    static let bubblePaddingH: CGFloat = 14
    static let bubblePaddingV: CGFloat = 10
    static let bubbleSpacingV: CGFloat = 6
    static let timestampSpacing: CGFloat = 4
    static let sideGutter: CGFloat = 16
    static let oppositeGutter: CGFloat = 64

    // MARK: Typography (Dynamic Type)

    static var bodyFont: UIFont { .preferredFont(forTextStyle: .body) }
    static var captionFont: UIFont { .preferredFont(forTextStyle: .caption1) }
    static var titleFont: UIFont { .preferredFont(forTextStyle: .headline) }
}
