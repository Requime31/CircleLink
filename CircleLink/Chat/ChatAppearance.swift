import UIKit

/// UIKit Soft Orbit tokens for Chat — mirrors `CLColor` / spacing / radii.
/// Visual chrome only; keep Dynamic Type fonts.
enum ChatAppearance {
    // MARK: Brand

    /// Rausch `#ff385c`
    static let primary = UIColor(red: 1.0, green: 0.22, blue: 0.36, alpha: 1.0)
    /// Warm apricot companion `#F4A261`
    static let companion = UIColor(red: 0.957, green: 0.635, blue: 0.380, alpha: 1.0)
    /// Soft apricot wash `#FFE8D6`
    static let companionSoft = UIColor(red: 1.0, green: 0.910, blue: 0.839, alpha: 1.0)

    // MARK: Text

    /// Near-black `#222222`
    static let ink = UIColor(red: 0.133, green: 0.133, blue: 0.133, alpha: 1.0)
    /// Muted `#6a6a6a`
    static let muted = UIColor(red: 0.416, green: 0.416, blue: 0.416, alpha: 1.0)
    /// Soft muted `#929292` — placeholders
    static let mutedSoft = UIColor(red: 0.573, green: 0.573, blue: 0.573, alpha: 1.0)
    /// Time on Rausch bubbles
    static let onPrimaryMuted = UIColor.white.withAlphaComponent(0.72)

    // MARK: Surfaces

    /// Soft blush page floor `#FFF6F2`
    static let canvas = UIColor(red: 1.0, green: 0.965, blue: 0.949, alpha: 1.0)
    /// Soft peach fill `#FFF0EA` — input field
    static let surfaceSoft = UIColor(red: 1.0, green: 0.941, blue: 0.918, alpha: 1.0)
    /// Warm hairline `#E8D9D2`
    static let hairline = UIColor(red: 0.910, green: 0.851, blue: 0.824, alpha: 1.0)

    // MARK: Bubbles

    /// Incoming: companionSoft wash (variant B)
    static let incomingBubble = companionSoft
    /// Outgoing: Rausch
    static let outgoingBubble = primary

    // MARK: Geometry

    static let bubbleRadius: CGFloat = 20
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
