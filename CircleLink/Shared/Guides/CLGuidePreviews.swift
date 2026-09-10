import SwiftUI

private struct CLGuidePreview: View {
    var longContent = false
    var body: some View {
        ZStack(alignment: .topLeading) {
            CLColor.canvas
            Button("Join") {}
                .buttonStyle(CLPrimaryButtonStyle())
                .frame(width: 112, height: 44)
                .position(x: 210, y: 230)
            CLGuideDimmer(target: CGRect(x: 154, y: 208, width: 112, height: 44))
            CLGuideSpotlight(target: CGRect(x: 154, y: 208, width: 112, height: 44))
            CLGuideTooltip(
                tip: .init(
                    id: "preview", series: .communities, target: .communityJoin,
                    title: "Join a community",
                    message: longContent
                        ? "Join to create posts, take part in conversations, and open the community group chat. This preview verifies wrapping at larger text sizes."
                        : "Join to post and open the group chat.",
                    version: 1
                ),
                placement: .tooltip(
                    frame: CGRect(x: 32, y: 280, width: 326, height: longContent ? 260 : 190),
                    arrowEdge: .top, arrowOffset: 178
                ),
                onDismiss: {}
            )
        }
        .frame(width: 390, height: 700)
    }
}

#Preview("Guide — Normal") { CLGuidePreview() }
#Preview("Guide — Dark") { CLGuidePreview().preferredColorScheme(.dark) }
#Preview("Guide — Long Content") { CLGuidePreview(longContent: true) }
#Preview("Guide — Accessibility Type") {
    CLGuidePreview(longContent: true).environment(\.dynamicTypeSize, .accessibility3)
}
#Preview("Guide — Narrow") { CLGuidePreview(longContent: true).frame(width: 320) }
