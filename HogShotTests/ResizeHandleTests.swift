import XCTest
@testable import HogShot

final class ResizeHandleTests: XCTestCase {
    private let rect = CGRect(x: 10, y: 20, width: 100, height: 50) // minX 10, minY 20, maxX 110, maxY 70

    func test_allCases_hasEightHandles() {
        XCTAssertEqual(ResizeHandle.allCases.count, 8)
    }

    func test_point_forEachHandle_matchesExpectedCorner() {
        XCTAssertEqual(ResizeHandle.topLeft.point(in: rect), CGPoint(x: 10, y: 20))
        XCTAssertEqual(ResizeHandle.top.point(in: rect), CGPoint(x: 60, y: 20))
        XCTAssertEqual(ResizeHandle.topRight.point(in: rect), CGPoint(x: 110, y: 20))
        XCTAssertEqual(ResizeHandle.right.point(in: rect), CGPoint(x: 110, y: 45))
        XCTAssertEqual(ResizeHandle.bottomRight.point(in: rect), CGPoint(x: 110, y: 70))
        XCTAssertEqual(ResizeHandle.bottom.point(in: rect), CGPoint(x: 60, y: 70))
        XCTAssertEqual(ResizeHandle.bottomLeft.point(in: rect), CGPoint(x: 10, y: 70))
        XCTAssertEqual(ResizeHandle.left.point(in: rect), CGPoint(x: 10, y: 45))
    }

    func test_applying_bottomRight_growsWidthAndHeight() {
        let result = ResizeHandle.bottomRight.applying(delta: CGPoint(x: 20, y: 10), to: rect)
        XCTAssertEqual(result, CGRect(x: 10, y: 20, width: 120, height: 60))
    }

    func test_applying_topLeft_movesOriginAndShrinksOppositely() {
        let result = ResizeHandle.topLeft.applying(delta: CGPoint(x: 5, y: 5), to: rect)
        XCTAssertEqual(result, CGRect(x: 15, y: 25, width: 95, height: 45))
    }

    func test_applying_right_onlyChangesWidth() {
        let result = ResizeHandle.right.applying(delta: CGPoint(x: -30, y: 999), to: rect)
        XCTAssertEqual(result, CGRect(x: 10, y: 20, width: 70, height: 50))
    }

    func test_applying_bottom_onlyChangesHeight() {
        let result = ResizeHandle.bottom.applying(delta: CGPoint(x: 999, y: 15), to: rect)
        XCTAssertEqual(result, CGRect(x: 10, y: 20, width: 100, height: 65))
    }

    func test_applying_left_movesOriginXAndAdjustsWidth() {
        let result = ResizeHandle.left.applying(delta: CGPoint(x: 5, y: 999), to: rect)
        XCTAssertEqual(result, CGRect(x: 15, y: 20, width: 95, height: 50))
    }

    func test_applying_top_movesOriginYAndAdjustsHeight() {
        let result = ResizeHandle.top.applying(delta: CGPoint(x: 999, y: 5), to: rect)
        XCTAssertEqual(result, CGRect(x: 10, y: 25, width: 100, height: 45))
    }

    /// Dragging a handle past the opposite edge inverts the rect; `.standardized`
    /// (applied at the end of `applying`) must always normalize it back to a
    /// non-negative-size rect rather than leaving width/height negative.
    func test_applying_bottomRight_pastOppositeCorner_normalizesToPositiveRect() {
        let result = ResizeHandle.bottomRight.applying(delta: CGPoint(x: -150, y: -100), to: rect)
        XCTAssertGreaterThanOrEqual(result.width, 0)
        XCTAssertGreaterThanOrEqual(result.height, 0)
        // dragging bottomRight (110,70) by (-150,-100) lands at (-40,-30); standardized
        // against the fixed topLeft corner (10,20) gives origin (-40,-30), size (50,50).
        XCTAssertEqual(result, CGRect(x: -40, y: -30, width: 50, height: 50))
    }

    func test_applying_topLeft_pastOppositeCorner_normalizesToPositiveRect() {
        let result = ResizeHandle.topLeft.applying(delta: CGPoint(x: 150, y: 100), to: rect)
        XCTAssertGreaterThanOrEqual(result.width, 0)
        XCTAssertGreaterThanOrEqual(result.height, 0)
        // dragging topLeft (10,20) by (150,100) lands at (160,120); standardized against
        // the fixed bottomRight corner (110,70) gives origin (110,70), size (50,50).
        XCTAssertEqual(result, CGRect(x: 110, y: 70, width: 50, height: 50))
    }

    func test_applying_zeroDelta_returnsSameRect() {
        for handle in ResizeHandle.allCases {
            XCTAssertEqual(handle.applying(delta: .zero, to: rect), rect, "\(handle) mutated the rect on a zero delta")
        }
    }
}
