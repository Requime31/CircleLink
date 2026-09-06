import SwiftUI

struct AppGuideHubView: View {
    @EnvironmentObject private var guideManager: ContextualGuideManager

    var body: some View {
        List {
            ForEach(CLGuideSeries.allCases, id: \.self) { series in
                Section {
                    guidePreview(for: series)
                    Button("Replay \(series.title) guide") { guideManager.replay(series) }
                        .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .clCanvasBackground()
        .navigationTitle("App Guide")
        .navigationBarTitleDisplayMode(.large)
        .onDisappear { guideManager.finishManualReplay() }
    }

    @ViewBuilder
    private func guidePreview(for series: CLGuideSeries) -> some View {
        switch series {
        case .connect:
            CLCard(variant: .outlined) {
                Label("Swipe to connect", systemImage: "hand.draw")
                    .frame(maxWidth: .infinity, minHeight: AccessibilityHelpers.minimumTouchTarget)
            }
            .clGuideTarget(.connectCard, instance: "manual")
        case .communities:
            VStack(spacing: CLSpacing.sm) {
                CLMembershipButton(state: .join, action: {})
                    .clGuideTarget(.communityJoin, instance: "manual")
                Button("Write a post") {}
                    .buttonStyle(CLPrimaryButtonStyle())
                    .clGuideTarget(.communityPost, instance: "manual")
                CLPostActions(actions: [
                    .init(id: "like", title: "Like", systemImage: "heart", action: {}),
                    .init(id: "comment", title: "Comment", systemImage: "bubble.left", action: {})
                ])
                .clGuideTarget(.communityReactions, instance: "manual")
            }
        case .chats:
            HStack {
                CLUnreadBadge(count: 3)
                    .clGuideTarget(.chatUnread, instance: "manual")
                Spacer()
                CLIconButton(systemImage: "arrow.down", accessibilityLabel: "Jump to new messages", action: {})
                    .clGuideTarget(.chatJump, instance: "manual")
            }
        case .profile:
            HStack {
                Button("Edit Profile") {}
                    .buttonStyle(CLPrimaryButtonStyle())
                    .clGuideTarget(.profileEdit, instance: "manual")
                CLIconButton(systemImage: "plus", accessibilityLabel: "Create profile post", action: {})
                    .clGuideTarget(.profilePost, instance: "manual")
            }
        }
    }
}

private extension CLGuideSeries {
    var title: String {
        switch self {
        case .connect: return "Connect"
        case .communities: return "Communities"
        case .chats: return "Chats"
        case .profile: return "Profile"
        }
    }
}
