import SwiftUI

struct CLMembershipButton: View {
    enum State: Equatable { case join, joined, pending, loading }

    let state: State
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: CLSpacing.xs) {
                if state == .loading { ProgressView() }
                Text(title)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(AnyCLButtonStyle(style: state == .join ? .emphasis : .secondary))
        .disabled(state == .loading || state == .pending)
        .accessibilityLabel(title)
    }

    private var title: String {
        switch state {
        case .join: return "Join"
        case .joined: return "Joined"
        case .pending: return "Request Pending"
        case .loading: return "Updating Membership"
        }
    }
}

struct CLSegmentedTabs<Selection: Hashable>: View {
    struct Item: Identifiable {
        let id: Selection
        let title: String
    }

    let items: [Item]
    @Binding var selection: Selection

    var body: some View {
        HStack(spacing: CLSpacing.xxs) {
            ForEach(items) { item in
                Button(item.title) { selection = item.id }
                    .font(CLTypography.footnote)
                    .foregroundStyle(selection == item.id ? CLColor.primaryStrong : CLColor.inkSecondary)
                    .frame(maxWidth: .infinity, minHeight: AccessibilityHelpers.minimumTouchTarget)
                    .background(selection == item.id ? CLColor.accentSoft : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: CLRadius.sm, style: .continuous))
                    .accessibilityAddTraits(selection == item.id ? .isSelected : [])
            }
        }
        .padding(CLSpacing.xxs)
        .background(CLColor.surfaceSoft)
        .clipShape(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous))
    }
}

struct CLPostAction: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    var isSelected = false
    let action: () -> Void
}

struct CLPostActions: View {
    let actions: [CLPostAction]

    var body: some View {
        HStack(spacing: CLSpacing.sm) {
            ForEach(actions) { item in
                Button(action: item.action) { Label(item.title, systemImage: item.systemImage) }
                    .font(CLTypography.footnote)
                    .foregroundStyle(item.isSelected ? CLColor.primary : CLColor.inkMuted)
                    .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
                    .accessibilityAddTraits(item.isSelected ? .isSelected : [])
            }
        }
    }
}

struct CLCommunityCard<Trailing: View>: View {
    let name: String
    var detail: String? = nil
    var imageURL: URL? = nil
    var variant: CLSurfaceVariant = .interactive
    private let trailing: Trailing

    init(name: String, detail: String? = nil, imageURL: URL? = nil, variant: CLSurfaceVariant = .interactive, @ViewBuilder trailing: () -> Trailing) {
        self.name = name
        self.detail = detail
        self.imageURL = imageURL
        self.variant = variant
        self.trailing = trailing()
    }

    var body: some View {
        CLCard(variant: variant) {
            HStack(spacing: CLSpacing.sm) {
                CLCommunityLabel(name: name, detail: detail, imageURL: imageURL)
                Spacer(minLength: CLSpacing.sm)
                trailing
            }
        }
    }
}

extension CLCommunityCard where Trailing == EmptyView {
    init(name: String, detail: String? = nil, imageURL: URL? = nil, variant: CLSurfaceVariant = .interactive) {
        self.init(name: name, detail: detail, imageURL: imageURL, variant: variant) { EmptyView() }
    }
}
