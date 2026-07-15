import UIKit

enum ChatAppearance {
    static let primary = UIColor(red: 1.0, green: 0.22, blue: 0.36, alpha: 1.0)
    static let ink = UIColor(red: 0.133, green: 0.133, blue: 0.133, alpha: 1.0)
    static let muted = UIColor(red: 0.416, green: 0.416, blue: 0.416, alpha: 1.0)
    static let canvas = UIColor.white
    static let surfaceSoft = UIColor(red: 0.969, green: 0.969, blue: 0.969, alpha: 1.0)
    static let incomingBubble = UIColor(red: 0.949, green: 0.949, blue: 0.949, alpha: 1.0)
    static let outgoingBubble = primary

    static var bodyFont: UIFont { .preferredFont(forTextStyle: .body) }
    static var captionFont: UIFont { .preferredFont(forTextStyle: .caption1) }
    static var titleFont: UIFont { .preferredFont(forTextStyle: .headline) }
}
