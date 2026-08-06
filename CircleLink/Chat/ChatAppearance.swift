import UIKit

/// UIKit tokens for Chat — mirrors `CLColor` / DESIGN.md (Sunset Parchment).
/// Visual chrome only; keep Dynamic Type fonts. Chat stays UIKit-isolated.
enum ChatAppearance {
    // MARK: Surfaces

    /// `#FCF9F8`
    static let canvas = UIColor(red: 0.988, green: 0.976, blue: 0.973, alpha: 1.0)
    /// `#FFFFFF`
    static let surface = UIColor.white
    /// `#F6F3F2`
    static let surfaceSoft = UIColor(red: 0.965, green: 0.953, blue: 0.949, alpha: 1.0)
    /// `#E8E4DF`
    static let hairline = UIColor(red: 0.910, green: 0.894, blue: 0.875, alpha: 1.0)
    /// `#DCC1B9`
    static let hairlineStrong = UIColor(red: 0.863, green: 0.757, blue: 0.725, alpha: 1.0)

    // MARK: Ink

    /// `#1C1B1B`
    static let ink = UIColor(red: 0.110, green: 0.106, blue: 0.106, alpha: 1.0)
    /// `#55423D`
    static let inkSecondary = UIColor(red: 0.333, green: 0.259, blue: 0.239, alpha: 1.0)
    /// `#88726C`
    static let inkMuted = UIColor(red: 0.533, green: 0.447, blue: 0.424, alpha: 1.0)
    /// `#B8B2A8`
    static let inkDisabled = UIColor(red: 0.722, green: 0.698, blue: 0.659, alpha: 1.0)

    // MARK: Primary (Sunset Clay)

    /// `#E67E5F`
    static let primary = UIColor(red: 0.902, green: 0.494, blue: 0.373, alpha: 1.0)
    /// `#9B442A`
    static let primaryPressed = UIColor(red: 0.608, green: 0.267, blue: 0.165, alpha: 1.0)
    /// `#FFDBD1`
    static let primarySoft = UIColor(red: 1.000, green: 0.859, blue: 0.820, alpha: 1.0)

    // MARK: Bubbles

    /// Mine: soft clay + dark ink
    static let outgoingBubble = primarySoft
    /// Theirs: white surface on parchment (better contrast than surfaceSoft)
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
    /// Fixed media width so image-only bubbles don’t collapse to the timestamp width.
    static let bubbleImageWidth: CGFloat = 220
    static let bubbleImageHeight: CGFloat = 180

    // MARK: Typography (Dynamic Type)

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
        static let bubble: CGFloat = 18
        static let image: CGFloat = 14
        static let field: CGFloat = 14
        static let avatar: CGFloat = 14
    }
}
