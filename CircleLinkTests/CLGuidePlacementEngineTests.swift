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
}
