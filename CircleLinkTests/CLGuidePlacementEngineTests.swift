import CoreGraphics
import Testing
@testable import CircleLink

struct CLGuidePlacementEngineTests {
    private let viewport = CGRect(x: 0, y: 0, width: 390, height: 844)
    private let safe = CGRect(x: 0, y: 59, width: 390, height: 751)

    @Test func placesTooltipBelowWhenThereIsNoRoomAbove() {
        let result = CLGuidePlacementEngine.place(.init(
            target: CGRect(x: 120, y: 70, width: 120, height: 44),
            viewport: viewport, safeBounds: safe,
            tooltipSize: CGSize(width: 300, height: 140), spacing: 16
        ))
        guard case let .tooltip(frame, edge, _) = result else {
            Issue.record("Expected tooltip placement")
            return
        }
        #expect(edge == .top)
        #expect(frame.minY >= 130)
        #expect(safe.contains(frame))
    }

    @Test func usesBottomPanelWhenNeitherSideFits() {
        let result = CLGuidePlacementEngine.place(.init(
            target: CGRect(x: 120, y: 360, width: 120, height: 100),
            viewport: viewport, safeBounds: safe,
            tooltipSize: CGSize(width: 350, height: 360), spacing: 16
        ))
        guard case let .bottomPanel(frame) = result else {
            Issue.record("Expected bottom panel fallback")
            return
        }
        #expect(safe.contains(frame))
        #expect(frame.maxY <= safe.maxY)
    }

    @Test func rejectsTargetsWithoutMeaningfulVisibleIntersection() {
        #expect(CLGuidePlacementEngine.visibleIntersection(
            target: CGRect(x: 20, y: 843, width: 100, height: 1), viewport: viewport
        ) == nil)
        #expect(CLGuidePlacementEngine.visibleIntersection(
            target: CGRect(x: 20, y: 800, width: 100, height: 44), viewport: viewport
        ) != nil)
    }
    @Test(arguments: [CGSize(width: 320, height: 568), CGSize(width: 568, height: 320),
                      CGSize(width: 390, height: 844)], [CGFloat(140), 360, 1_200])
    func keepsLongAndNarrowTooltipsInsideVisibleBounds(size: CGSize, contentHeight: CGFloat) {
        let viewport = CGRect(origin: .zero, size: size)
        let safe = viewport.insetBy(dx: 0, dy: 24)
        for targetY in [CGFloat(-80), 30, size.height / 2, size.height - 20, size.height + 80] {
            let placement = CLGuidePlacementEngine.place(.init(
                target: CGRect(x: size.width - 40, y: targetY, width: 100, height: 44),
                viewport: viewport, safeBounds: safe,
                tooltipSize: CGSize(width: 340, height: contentHeight), spacing: 16
            ))
            switch placement {
            case let .tooltip(frame, edge, offset):
                #expect(safe.contains(frame))
                let arrow = CGRect(x: frame.minX + offset - 10,
                                   y: edge == .top ? frame.minY - 10 : frame.maxY,
                                   width: 20, height: 10)
                #expect(safe.contains(arrow))
            case let .bottomPanel(frame):
                #expect(safe.contains(frame))
                #expect(frame.height <= safe.height)
            }
        }
    }

    @Test func intersectsSafeBoundsWithActualViewport() {
        let viewport = CGRect(x: 0, y: 0, width: 320, height: 300)
        let placement = CLGuidePlacementEngine.place(.init(
            target: CGRect(x: 20, y: 100, width: 100, height: 100),
            viewport: viewport, safeBounds: CGRect(x: 0, y: 0, width: 500, height: 800),
            tooltipSize: CGSize(width: 340, height: 900), spacing: 16
        ))
        guard case let .bottomPanel(frame) = placement else {
            Issue.record("Expected scrollable panel")
            return
        }
        #expect(viewport.contains(frame))
    }

    @Test func preservesMeasuredWidthInBottomPanel() {
        let placement = CLGuidePlacementEngine.place(.init(
            target: CGRect(x: 10, y: 80, width: 300, height: 650),
            viewport: viewport, safeBounds: safe,
            tooltipSize: CGSize(width: 300, height: 220), spacing: 16
        ))
        guard case let .bottomPanel(frame) = placement else {
            Issue.record("Expected panel")
            return
        }
        #expect(frame.width == 300)
    }

}
