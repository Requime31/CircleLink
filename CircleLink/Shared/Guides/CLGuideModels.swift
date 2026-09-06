import CoreGraphics
import Foundation

nonisolated enum CLGuideSeries: String, CaseIterable, Sendable {
    case connect, communities, chats, profile
}

nonisolated enum CLGuideTarget: String, CaseIterable, Sendable {
    case connectCard
    case communityJoin
    case communityPost
    case communityReactions
    case chatUnread
    case chatJump
    case profilePost
    case profileEdit
}

nonisolated struct CLGuideTargetID: Hashable, Sendable {
    let target: CLGuideTarget
    let instance: String?

    init(_ target: CLGuideTarget, instance: String? = nil) {
        self.target = target
        self.instance = instance
    }
}

nonisolated struct CLGuideTip: Identifiable, Hashable, Sendable {
    let id: String
    let series: CLGuideSeries
    let target: CLGuideTarget
    let title: String
    let message: String
    let version: Int

    static let catalog: [CLGuideTip] = [
        .init(id: "connect-card", series: .connect, target: .connectCard,
              title: "Meet someone new", message: "Swipe right to connect or left to pass.", version: 1),
        .init(id: "community-join", series: .communities, target: .communityJoin,
              title: "Join a community", message: "Join to post and open the group chat.", version: 1),
        .init(id: "community-post", series: .communities, target: .communityPost,
              title: "Share with the community", message: "Create a post for everyone in this community.", version: 1),
        .init(id: "community-reactions", series: .communities, target: .communityReactions,
              title: "React to posts", message: "Use these actions to take part in the conversation.", version: 1),
        .init(id: "chat-unread", series: .chats, target: .chatUnread,
              title: "Unread messages", message: "This badge shows how many messages are waiting.", version: 1),
        .init(id: "chat-jump", series: .chats, target: .chatJump,
              title: "Return to new messages", message: "Jump back when newer messages are below.", version: 1),
        .init(id: "profile-post", series: .profile, target: .profilePost,
              title: "Create a profile post", message: "Share a photo or a thought from your profile.", version: 1),
        .init(id: "profile-edit", series: .profile, target: .profileEdit,
              title: "Keep your profile current", message: "Update your photo, bio, and interests here.", version: 1)
    ]
}

nonisolated enum CLGuidePresentationMode: Equatable, Sendable {
    case automatic
    case manual(series: CLGuideSeries)
}

nonisolated struct CLGuidePlacementInput: Equatable, Sendable {
    let target: CGRect
    let viewport: CGRect
    let safeBounds: CGRect
    let tooltipSize: CGSize
    let spacing: CGFloat
}

nonisolated enum CLGuidePlacement: Equatable, Sendable {
    case tooltip(frame: CGRect, arrowEdge: CLGuideArrowEdge, arrowOffset: CGFloat)
    case bottomPanel(frame: CGRect)
}

nonisolated enum CLGuideArrowEdge: Equatable, Sendable { case top, bottom }

nonisolated enum CLGuidePlacementEngine {
    static func place(_ input: CLGuidePlacementInput) -> CLGuidePlacement {
        let horizontalInset = max(16, input.spacing)
        let available = input.safeBounds.insetBy(dx: horizontalInset, dy: input.spacing)
        let width = min(input.tooltipSize.width, available.width)
        let height = input.tooltipSize.height
        let aboveY = input.target.minY - input.spacing - height
        let belowY = input.target.maxY + input.spacing
        let centeredX = min(max(input.target.midX - width / 2, available.minX), available.maxX - width)

        if aboveY >= available.minY {
            let frame = CGRect(x: centeredX, y: aboveY, width: width, height: height)
            return .tooltip(frame: frame, arrowEdge: .bottom,
                            arrowOffset: min(max(input.target.midX - frame.minX, 20), width - 20))
        }
        if belowY + height <= available.maxY {
            let frame = CGRect(x: centeredX, y: belowY, width: width, height: height)
            return .tooltip(frame: frame, arrowEdge: .top,
                            arrowOffset: min(max(input.target.midX - frame.minX, 20), width - 20))
        }
        let panelHeight = min(height, available.height)
        return .bottomPanel(frame: CGRect(
            x: available.minX,
            y: available.maxY - panelHeight,
            width: available.width,
            height: panelHeight
        ))
    }

    static func visibleIntersection(target: CGRect, viewport: CGRect) -> CGRect? {
        let intersection = target.intersection(viewport)
        guard !intersection.isNull, intersection.width >= 2, intersection.height >= 2 else { return nil }
        guard target.width > 0, target.height > 0,
              intersection.width * intersection.height >= target.width * target.height * 0.5 else { return nil }
        return intersection
    }
}
