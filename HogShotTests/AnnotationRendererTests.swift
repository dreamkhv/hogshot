import XCTest
import AppKit
@testable import HogShot

/// Exercises `AnnotationRenderer`'s drawing contract: annotation points live in
/// top-left/y-down pixel space, and every tool must draw where its points say it
/// should — see the coordinate-space contract documented on `AnnotationRenderer` itself.
final class AnnotationRendererTests: XCTestCase {

    // MARK: - drawImageRightSideUp (the exact regression this app hit)

    /// This is the direct regression test for the "screenshots render upside down"
    /// bug: `drawImageRightSideUp` must undo the ambient flip for `CGImage` draws so
    /// the image comes out in the same visual orientation it was captured in.
    func test_drawImageRightSideUp_preservesVisualOrientation() {
        let size = 40
        let source = makeTopBottomImage(width: size, height: size, top: .red, bottom: .blue)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(
            data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        // The one ambient flip every real caller in this app applies before drawing.
        ctx.translateBy(x: 0, y: CGFloat(size))
        ctx.scaleBy(x: 1, y: -1)

        AnnotationRenderer.drawImageRightSideUp(source, in: CGRect(x: 0, y: 0, width: size, height: size), ctx: ctx)
        let out = ctx.makeImage()!

        let top = pixel(of: out, x: size / 2, y: 1)
        let bottom = pixel(of: out, x: size / 2, y: size - 2)
        XCTAssertGreaterThan(top.r, 180, "expected red near the top of the drawn image, got \(top)")
        XCTAssertGreaterThan(bottom.b, 180, "expected blue near the bottom of the drawn image, got \(bottom)")
    }

    // MARK: - defensive guards

    func test_draw_skipsAnnotationsWithTooFewPointsWithoutTouchingCanvas() {
        let source = makeSolidImage(width: 50, height: 50, color: .white)
        // Every tool with exactly one point: line/rect/ellipse/pen/highlighter/pixelate/arrow
        // all require >= 2 points; text with the default empty string also no-ops.
        let degenerate = AnnotationTool.allCases.map { Annotation(tool: $0, points: [CGPoint(x: 25, y: 25)]) }
        let out = renderAnnotations(degenerate, width: 50, height: 50, source: source)

        for x in stride(from: 0, to: 50, by: 5) {
            for y in stride(from: 0, to: 50, by: 5) {
                let p = pixel(of: out, x: x, y: y)
                XCTAssertEqual(p.r, 255, "pixel (\(x),\(y)) was touched by a degenerate annotation")
            }
        }
    }

    func test_draw_withNoAnnotations_leavesCanvasUntouched() {
        let source = makeSolidImage(width: 20, height: 20, color: .white)
        let out = renderAnnotations([], width: 20, height: 20, source: source)
        let p = pixel(of: out, x: 10, y: 10)
        XCTAssertEqual(p.r, 255)
    }

    // MARK: - per-tool drawing

    func test_rectangle_strokesEdgesButLeavesInteriorUntouched() {
        let source = makeSolidImage(width: 100, height: 100, color: .white)
        let annotation = Annotation(tool: .rectangle, points: [CGPoint(x: 20, y: 20), CGPoint(x: 80, y: 80)], color: .black, lineWidth: 4)
        let out = renderAnnotations([annotation], width: 100, height: 100, source: source)

        let topEdge = pixel(of: out, x: 50, y: 20)
        XCTAssertTrue(approxEqual(topEdge.r, 0), "expected a black stroke on the top edge, got \(topEdge)")

        let interior = pixel(of: out, x: 50, y: 50)
        XCTAssertEqual(interior.r, 255, "rectangle tool must not fill its interior")
    }

    func test_ellipse_strokesBoundaryButLeavesInteriorUntouched() {
        let source = makeSolidImage(width: 100, height: 100, color: .white)
        let annotation = Annotation(tool: .ellipse, points: [CGPoint(x: 10, y: 10), CGPoint(x: 90, y: 90)], color: .black, lineWidth: 4)
        let out = renderAnnotations([annotation], width: 100, height: 100, source: source)

        let topOfEllipse = pixel(of: out, x: 50, y: 10)
        XCTAssertTrue(approxEqual(topOfEllipse.r, 0), "expected a black stroke at the ellipse's top, got \(topOfEllipse)")

        let interior = pixel(of: out, x: 50, y: 50)
        XCTAssertEqual(interior.r, 255, "ellipse tool must not fill its interior")
    }

    func test_line_drawsStraightStrokeBetweenItsTwoPoints() {
        let source = makeSolidImage(width: 100, height: 100, color: .white)
        let annotation = Annotation(tool: .line, points: [CGPoint(x: 10, y: 50), CGPoint(x: 90, y: 50)], color: .black, lineWidth: 4)
        let out = renderAnnotations([annotation], width: 100, height: 100, source: source)

        let onLine = pixel(of: out, x: 50, y: 50)
        XCTAssertTrue(approxEqual(onLine.r, 0), "expected the stroke on the line itself, got \(onLine)")

        let offLine = pixel(of: out, x: 50, y: 10)
        XCTAssertEqual(offLine.r, 255, "pixels off the line must be untouched")
    }

    func test_pen_followsMultiPointPath() {
        let source = makeSolidImage(width: 100, height: 100, color: .white)
        let annotation = Annotation(
            tool: .pen,
            points: [CGPoint(x: 10, y: 90), CGPoint(x: 10, y: 50), CGPoint(x: 90, y: 50)],
            color: .black, lineWidth: 4
        )
        let out = renderAnnotations([annotation], width: 100, height: 100, source: source)

        let onVerticalLeg = pixel(of: out, x: 10, y: 70)
        XCTAssertTrue(approxEqual(onVerticalLeg.r, 0), "expected stroke on the pen path's vertical leg, got \(onVerticalLeg)")

        let onHorizontalLeg = pixel(of: out, x: 50, y: 50)
        XCTAssertTrue(approxEqual(onHorizontalLeg.r, 0), "expected stroke on the pen path's horizontal leg, got \(onHorizontalLeg)")

        let offPath = pixel(of: out, x: 50, y: 10)
        XCTAssertEqual(offPath.r, 255)
    }

    func test_highlighter_multipliesTranslucentColorOverBackground() {
        let source = makeSolidImage(width: 100, height: 100, color: .white)
        let annotation = Annotation(tool: .highlighter, points: [CGPoint(x: 10, y: 50), CGPoint(x: 90, y: 50)], color: .yellow, lineWidth: 4)
        let out = renderAnnotations([annotation], width: 100, height: 100, source: source)

        let onStroke = pixel(of: out, x: 50, y: 50)
        // yellow (1,1,0) multiplied over white at alpha 0.4 keeps red/green near white
        // but pulls blue down noticeably — a highlighter, not an opaque fill.
        XCTAssertGreaterThan(onStroke.r, 200)
        XCTAssertGreaterThan(onStroke.g, 200)
        XCTAssertLessThan(onStroke.b, 220, "expected the highlighter to visibly tint blue down, got \(onStroke)")
    }

    func test_arrow_drawsShaftAndHead() {
        let source = makeSolidImage(width: 100, height: 100, color: .white)
        let annotation = Annotation(tool: .arrow, points: [CGPoint(x: 10, y: 50), CGPoint(x: 90, y: 50)], color: .black, lineWidth: 4)
        let out = renderAnnotations([annotation], width: 100, height: 100, source: source)

        let onShaft = pixel(of: out, x: 30, y: 50)
        XCTAssertTrue(approxEqual(onShaft.r, 0), "expected the shaft stroke, got \(onShaft)")

        let onHead = pixel(of: out, x: 85, y: 50)
        XCTAssertTrue(approxEqual(onHead.r, 0), "expected the filled arrowhead near the end point, got \(onHead)")

        let awayFromArrow = pixel(of: out, x: 50, y: 10)
        XCTAssertEqual(awayFromArrow.r, 255)
    }

    func test_text_rendersGlyphPixelsNearItsOrigin() {
        let source = makeSolidImage(width: 100, height: 100, color: .white)
        let annotation = Annotation(tool: .text, points: [CGPoint(x: 10, y: 10)], color: .black, lineWidth: 4, text: "A", fontSize: 28)
        let out = renderAnnotations([annotation], width: 100, height: 100, source: source)

        var foundDarkPixel = false
        for x in 10..<45 {
            for y in 10..<45 {
                if pixel(of: out, x: x, y: y).r < 200 {
                    foundDarkPixel = true
                    break
                }
            }
            if foundDarkPixel { break }
        }
        XCTAssertTrue(foundDarkPixel, "expected the 'A' glyph to render some dark pixels near its origin")
    }

    func test_text_withEmptyString_drawsNothing() {
        let source = makeSolidImage(width: 40, height: 40, color: .white)
        let annotation = Annotation(tool: .text, points: [CGPoint(x: 5, y: 5)], text: "")
        let out = renderAnnotations([annotation], width: 40, height: 40, source: source)
        for x in stride(from: 0, to: 40, by: 4) {
            for y in stride(from: 0, to: 40, by: 4) {
                XCTAssertEqual(pixel(of: out, x: x, y: y).r, 255)
            }
        }
    }

    /// `CIFilter.pixellate`'s exact per-pixel cell/blend layout is a Core Image
    /// implementation detail (observed empirically to vary in non-obvious ways with
    /// image size and row), not something this app's code controls or should have to
    /// predict. What `AnnotationRenderer.pixelate` itself is responsible for — and what
    /// this asserts — is: replace its rect with *something* derived from the source,
    /// and never touch pixels outside that rect.
    func test_pixelate_overwritesItsRectAndLeavesOutsideUntouched() {
        let size = 100
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                             space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        // A sentinel color that a black-source pixelate output can never produce, so any
        // pixel still showing it proves pixelate never wrote there.
        ctx.setFillColor(NSColor(red: 0, green: 1, blue: 0, alpha: 1).cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
        ctx.translateBy(x: 0, y: CGFloat(size))
        ctx.scaleBy(x: 1, y: -1)

        let source = makeSolidImage(width: size, height: size, color: .black)
        let annotation = Annotation(tool: .pixelate, points: [CGPoint(x: 20, y: 20), CGPoint(x: 80, y: 80)], lineWidth: 16)
        AnnotationRenderer.draw([annotation], into: ctx, source: source)
        let out = ctx.makeImage()!

        let isSentinelGreen: (RGBA) -> Bool = { $0.r == 0 && $0.g == 255 && $0.b == 0 }

        let insideRect = pixel(of: out, x: 50, y: 50)
        XCTAssertFalse(isSentinelGreen(insideRect), "expected pixelate to overwrite its rect with filtered content, got untouched sentinel \(insideRect)")

        let outsideRect = pixel(of: out, x: 5, y: 5)
        XCTAssertTrue(isSentinelGreen(outsideRect), "pixelate must not touch pixels outside its own rect, got \(outsideRect)")
    }

    func test_pixelate_withRectOutsideImageBounds_isSkippedWithoutCrashing() {
        let source = makeSolidImage(width: 30, height: 30, color: .white)
        let annotation = Annotation(tool: .pixelate, points: [CGPoint(x: 1000, y: 1000), CGPoint(x: 1050, y: 1050)], lineWidth: 8)
        let out = renderAnnotations([annotation], width: 30, height: 30, source: source)
        XCTAssertEqual(pixel(of: out, x: 15, y: 15).r, 255)
    }
}
