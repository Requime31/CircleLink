import SwiftUI

enum CLSurfaceVariant: Equatable {
    case plain
    case outlined
    case elevated
    case interactive
    case selected
    case destructive
}

struct CLSurface<Content: View>: View {
    var variant: CLSurfaceVariant = .plain
    var radius: CGFloat = CLRadius.lg
    var padding: CGFloat = CLSpacing.md
    private let content: Content

    init(
        variant: CLSurfaceVariant = .plain,
        radius: CGFloat = CLRadius.lg,
        padding: CGFloat = CLSpacing.md,
        @ViewBuilder content: () -> Content
    ) {
        self.variant = variant
        self.radius = radius
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background)
            .clipShape(shape)
            .overlay(shape.stroke(border, lineWidth: borderWidth))
            .shadow(color: shadowColor, radius: shadowRadius, y: shadowY)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }

    private var background: Color {
        switch variant {
        case .selected: return CLColor.accentSoft
        case .destructive: return CLColor.errorSoft
        case .interactive: return CLColor.surface
        default: return CLColor.surface
        }
    }

    private var border: Color {
        switch variant {
        case .outlined, .interactive: return CLColor.hairline
        case .selected: return CLColor.primary
        case .destructive: return CLColor.error
        case .plain, .elevated: return .clear
        }
    }

    private var borderWidth: CGFloat {
        switch variant {
        case .plain, .elevated: return 0
        default: return 1
        }
    }

    private var shadowColor: Color { variant == .elevated ? CLShadow.elevatedColor : .clear }
    private var shadowRadius: CGFloat { variant == .elevated ? CLShadow.elevatedRadius : 0 }
    private var shadowY: CGFloat { variant == .elevated ? CLShadow.elevatedY : 0 }
}

struct CLCard<Content: View>: View {
    var variant: CLSurfaceVariant = .outlined
    var padding: CGFloat = CLSpacing.md
    private let content: Content

    init(
        variant: CLSurfaceVariant = .outlined,
        padding: CGFloat = CLSpacing.md,
        @ViewBuilder content: () -> Content
    ) {
        self.variant = variant
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        CLSurface(variant: variant, radius: CLRadius.xl, padding: padding) { content }
    }
}

struct CLPressableCardStyle: ButtonStyle {
    var variant: CLSurfaceVariant = .interactive
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        CLSurface(variant: variant, radius: CLRadius.xl, padding: 0) {
            configuration.label
        }
        .opacity(configuration.isPressed ? 0.88 : 1)
        .scaleEffect(configuration.isPressed && reduceMotion == false ? 0.985 : 1)
        .animation(reduceMotion ? nil : CLMotion.micro, value: configuration.isPressed)
    }
}

struct CLHairline: View {
    var color = CLColor.hairline
    var inset: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: 1 / UIScreen.main.scale)
            .padding(.horizontal, inset)
            .accessibilityHidden(true)
    }
}

struct CLSectionHeader<Trailing: View>: View {
    let title: String
    var subtitle: String? = nil
    private let trailing: Trailing

    init(
        _ title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: CLSpacing.sm) {
            VStack(alignment: .leading, spacing: CLSpacing.xxs) {
                Text(title)
                    .font(CLTypography.headline)
                    .foregroundStyle(CLColor.ink)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle).font(CLTypography.footnote).foregroundStyle(CLColor.inkMuted)
                }
            }
            Spacer(minLength: CLSpacing.sm)
            trailing
        }
    }
}

extension CLSectionHeader where Trailing == EmptyView {
    init(_ title: String, subtitle: String? = nil) {
        self.init(title, subtitle: subtitle) { EmptyView() }
    }
}

struct CLScrollableScreen<Header: View, Content: View>: View {
    var contentSpacing: CGFloat = CLSpacing.lg
    var horizontalPadding: CGFloat = CLSpacing.screenHorizontal
    private let header: Header
    private let content: Content

    init(
        contentSpacing: CGFloat = CLSpacing.lg,
        horizontalPadding: CGFloat = CLSpacing.screenHorizontal,
        @ViewBuilder header: () -> Header,
        @ViewBuilder content: () -> Content
    ) {
        self.contentSpacing = contentSpacing
        self.horizontalPadding = horizontalPadding
        self.header = header()
        self.content = content()
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: contentSpacing) { content }
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, CLSpacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .safeAreaInset(edge: .top, spacing: 0) { header }
        .scrollDismissesKeyboard(.interactively)
        .clCanvasBackground()
    }
}

struct CLFlowLayout: Layout {
    var horizontalSpacing: CGFloat = CLSpacing.xs
    var verticalSpacing: CGFloat = CLSpacing.xs

    struct Result: Equatable {
        let size: CGSize
        let positions: [CGPoint]
    }

    static func arrange(sizes: [CGSize], maxWidth: CGFloat?, horizontalSpacing: CGFloat, verticalSpacing: CGFloat) -> Result {
        let boundedWidth = maxWidth.flatMap { $0.isFinite ? max(0, $0) : nil }
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var contentWidth: CGFloat = 0

        for size in sizes {
            if let boundedWidth, x > 0, x + size.width > boundedWidth {
                x = 0
                y += rowHeight + verticalSpacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            contentWidth = max(contentWidth, x + size.width)
            x += size.width + horizontalSpacing
        }

        return Result(
            size: CGSize(width: boundedWidth ?? contentWidth, height: sizes.isEmpty ? 0 : y + rowHeight),
            positions: positions
        )
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        result(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let layout = result(proposal: proposal, subviews: subviews)
        for (index, position) in layout.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: ProposedViewSize(subviews[index].sizeThatFits(.unspecified))
            )
        }
    }

    private func result(proposal: ProposedViewSize, subviews: Subviews) -> Result {
        Self.arrange(
            sizes: subviews.map { $0.sizeThatFits(.unspecified) },
            maxWidth: proposal.width,
            horizontalSpacing: horizontalSpacing,
            verticalSpacing: verticalSpacing
        )
    }
}
