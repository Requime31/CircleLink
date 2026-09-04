import CoreGraphics
import Testing
@testable import CircleLink

@MainActor
struct CLFlowLayoutTests {
    @Test func wrapsItemsAtBoundedWidth() {
        let result = CLFlowLayout.arrange(
            sizes: [CGSize(width: 60, height: 20), CGSize(width: 50, height: 24), CGSize(width: 30, height: 18)],
            maxWidth: 100,
            horizontalSpacing: 8,
            verticalSpacing: 6
        )

        #expect(result.positions == [CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 26), CGPoint(x: 58, y: 26)])
        #expect(result.size == CGSize(width: 100, height: 50))
    }

    @Test func usesContentWidthWhenUnbounded() {
        let result = CLFlowLayout.arrange(
            sizes: [CGSize(width: 20, height: 10), CGSize(width: 30, height: 12)],
            maxWidth: nil,
            horizontalSpacing: 4,
            verticalSpacing: 4
        )

        #expect(result.size == CGSize(width: 54, height: 12))
        #expect(result.positions == [CGPoint(x: 0, y: 0), CGPoint(x: 24, y: 0)])
    }

    @Test func emptyInputHasZeroHeight() {
        let result = CLFlowLayout.arrange(sizes: [], maxWidth: 120, horizontalSpacing: 8, verticalSpacing: 8)
        #expect(result.size == CGSize(width: 120, height: 0))
        #expect(result.positions.isEmpty)
    }
}
