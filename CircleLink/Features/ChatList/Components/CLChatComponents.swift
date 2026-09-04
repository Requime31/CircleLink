import SwiftUI

struct CLChatInfoActionTile: View {
    let title: String
    let systemImage: String
    var role: ButtonRole? = nil
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            VStack(spacing: CLSpacing.xs) {
                Image(systemName: systemImage).font(.title2).accessibilityHidden(true)
                Text(title).font(CLTypography.footnote).multilineTextAlignment(.center)
            }
            .foregroundStyle(role == .destructive ? CLColor.error : CLColor.ink)
            .frame(maxWidth: .infinity, minHeight: 88)
        }
        .buttonStyle(CLPressableCardStyle(variant: role == .destructive ? .destructive : .interactive))
        .accessibilityLabel(title)
    }
}

struct CLChatParticipantRow<Trailing: View>: View {
    let name: String
    var detail: String? = nil
    var avatarURL: URL? = nil
    private let trailing: Trailing

    init(name: String, detail: String? = nil, avatarURL: URL? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.name = name
        self.detail = detail
        self.avatarURL = avatarURL
        self.trailing = trailing()
    }

    var body: some View {
        CLPersonRow(name: name, detail: detail, avatarURL: avatarURL) { trailing }
    }
}

struct CLChatMediaGrid<Item: Identifiable, Content: View>: View {
    let items: [Item]
    private let content: (Item) -> Content

    init(items: [Item], @ViewBuilder content: @escaping (Item) -> Content) {
        self.items = items
        self.content = content
    }

    var body: some View {
        CLMediaGrid(
            items: items,
            configuration: CLMediaGridConfiguration(minimumItemWidth: 104, spacing: CLSpacing.xxs, aspectRatio: 1),
            content: content
        )
    }
}
