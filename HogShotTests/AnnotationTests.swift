import XCTest
import AppKit
@testable import HogShot

final class AnnotationTests: XCTestCase {

    func test_boundingBox_forEmptyPoints_isZero() {
        let annotation = Annotation(tool: .pen, points: [])
        XCTAssertEqual(annotation.boundingBox, .zero)
    }

    func test_boundingBox_forPenTool_padsByLineWidth() {
        let annotation = Annotation(tool: .pen, points: [CGPoint(x: 10, y: 10), CGPoint(x: 50, y: 40)], lineWidth: 6)
        // pen padding == lineWidth (not lineWidth * 2, unlike every other tool)
        let expected = CGRect(x: 10 - 6, y: 10 - 6, width: 40 + 12, height: 30 + 12)
        XCTAssertEqual(annotation.boundingBox, expected)
    }

    func test_boundingBox_forNonPenTool_padsByDoubleLineWidth() {
        let annotation = Annotation(tool: .rectangle, points: [CGPoint(x: 10, y: 10), CGPoint(x: 50, y: 40)], lineWidth: 6)
        let expected = CGRect(x: 10 - 12, y: 10 - 12, width: 40 + 24, height: 30 + 24)
        XCTAssertEqual(annotation.boundingBox, expected)
    }

    func test_boundingBox_forSinglePoint_isDegenerateButPadded() {
        let annotation = Annotation(tool: .arrow, points: [CGPoint(x: 5, y: 5)], lineWidth: 4)
        let expected = CGRect(x: 5 - 8, y: 5 - 8, width: 16, height: 16)
        XCTAssertEqual(annotation.boundingBox, expected)
    }

    func test_boundingBox_normalizesUnsortedPoints() {
        // points out of min/max order should still produce a well-formed rect
        let annotation = Annotation(tool: .rectangle, points: [CGPoint(x: 80, y: 5), CGPoint(x: 10, y: 90), CGPoint(x: 40, y: 40)], lineWidth: 2)
        let box = annotation.boundingBox
        XCTAssertGreaterThanOrEqual(box.width, 0)
        XCTAssertGreaterThanOrEqual(box.height, 0)
        XCTAssertEqual(box.minX, 10 - 4)
        XCTAssertEqual(box.maxX, 80 + 4)
        XCTAssertEqual(box.minY, 5 - 4)
        XCTAssertEqual(box.maxY, 90 + 4)
    }

    func test_annotationTool_allCasesHaveNonEmptySymbolNameAndMatchingID() {
        for tool in AnnotationTool.allCases {
            XCTAssertFalse(tool.symbolName.isEmpty, "\(tool) has no symbol name")
            XCTAssertEqual(tool.id, tool.rawValue)
        }
        XCTAssertEqual(AnnotationTool.allCases.count, 8)
    }
}
