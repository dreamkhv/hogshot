import XCTest
import AppKit
@testable import HogShot

final class ExportServiceTests: XCTestCase {

    func test_flattenedImage_fullFrameCrop_preservesOrientationAndSize() throws {
        let source = makeTopBottomImage(width: 100, height: 100, top: .red, bottom: .blue)
        let out = try ExportService.flattenedImage(source: source, cropRect: CGRect(x: 0, y: 0, width: 100, height: 100), annotations: [])

        XCTAssertEqual(out.width, 100)
        XCTAssertEqual(out.height, 100)
        XCTAssertGreaterThan(pixel(of: out, x: 50, y: 1).r, 180, "top of the export should still be red")
        XCTAssertGreaterThan(pixel(of: out, x: 50, y: 98).b, 180, "bottom of the export should still be blue")
    }

    func test_flattenedImage_partialCrop_returnsOnlyRequestedRegion() throws {
        let source = makeTopBottomImage(width: 100, height: 100, top: .red, bottom: .blue)

        let topHalf = try ExportService.flattenedImage(source: source, cropRect: CGRect(x: 0, y: 0, width: 100, height: 50), annotations: [])
        XCTAssertEqual(topHalf.height, 50)
        XCTAssertGreaterThan(pixel(of: topHalf, x: 50, y: 25).r, 180, "expected only the red half back")

        let bottomHalf = try ExportService.flattenedImage(source: source, cropRect: CGRect(x: 0, y: 50, width: 100, height: 50), annotations: [])
        XCTAssertEqual(bottomHalf.height, 50)
        XCTAssertGreaterThan(pixel(of: bottomHalf, x: 50, y: 25).b, 180, "expected only the blue half back")
    }

    func test_flattenedImage_clampsCropRectToSourceBounds() throws {
        let source = makeTopBottomImage(width: 100, height: 100, top: .red, bottom: .blue)
        let oversized = CGRect(x: -20, y: -20, width: 140, height: 140)
        let out = try ExportService.flattenedImage(source: source, cropRect: oversized, annotations: [])

        XCTAssertEqual(out.width, 100)
        XCTAssertEqual(out.height, 100)
    }

    func test_flattenedImage_cropRectFullyOutsideBounds_throwsCropFailed() {
        let source = makeSolidImage(width: 50, height: 50, color: .white)
        let outside = CGRect(x: 1000, y: 1000, width: 10, height: 10)

        XCTAssertThrowsError(try ExportService.flattenedImage(source: source, cropRect: outside, annotations: [])) { error in
            guard let exportError = error as? ExportError else {
                return XCTFail("expected ExportError, got \(error)")
            }
            guard case .cropFailed = exportError else {
                return XCTFail("expected .cropFailed, got \(exportError)")
            }
        }
    }

    func test_flattenedImage_translatesAnnotationsIntoCropRelativeSpace() throws {
        let source = makeSolidImage(width: 100, height: 100, color: .white)
        // Annotation points are always in full-source pixel space, same as OverlayView
        // stores them; ExportService must shift them into crop-relative space itself.
        let cropRect = CGRect(x: 30, y: 30, width: 40, height: 40)
        let rectAnnotation = Annotation(tool: .rectangle, points: [CGPoint(x: 40, y: 40), CGPoint(x: 60, y: 60)], color: .black, lineWidth: 4)

        let out = try ExportService.flattenedImage(source: source, cropRect: cropRect, annotations: [rectAnnotation])
        XCTAssertEqual(out.width, 40)
        XCTAssertEqual(out.height, 40)

        let leftEdge = pixel(of: out, x: 10, y: 20) // full-image (40,50) -> crop-relative (10,20)
        XCTAssertTrue(approxEqual(leftEdge.r, 0), "expected the rectangle's stroke at crop-relative (10,20), got \(leftEdge)")

        let interior = pixel(of: out, x: 20, y: 20)
        XCTAssertEqual(interior.r, 255, "rectangle must not fill its interior")
    }

    func test_pngData_roundTripsThroughDecoding() throws {
        let source = makeTopBottomImage(width: 20, height: 20, top: .red, bottom: .blue)
        guard let data = ExportService.pngData(for: source) else {
            return XCTFail("expected PNG data")
        }
        XCTAssertGreaterThan(data.count, 0)

        guard let decoded = NSBitmapImageRep(data: data)?.cgImage else {
            return XCTFail("could not decode the PNG back into an image")
        }
        XCTAssertEqual(decoded.width, 20)
        XCTAssertEqual(decoded.height, 20)
        XCTAssertGreaterThan(pixel(of: decoded, x: 10, y: 1).r, 180)
        XCTAssertGreaterThan(pixel(of: decoded, x: 10, y: 18).b, 180)
    }

    func test_save_writesReadablePNGToDisk() throws {
        let source = makeSolidImage(width: 10, height: 10, color: .green)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
        defer { try? FileManager.default.removeItem(at: url) }

        try ExportService.save(source, to: url)

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let readBack = try Data(contentsOf: url)
        XCTAssertGreaterThan(readBack.count, 0)
        XCTAssertNotNil(NSBitmapImageRep(data: readBack), "written file should decode as a valid image")
    }

    func test_save_toUnwritableDirectory_throws() {
        let source = makeSolidImage(width: 10, height: 10, color: .green)
        let badURL = URL(fileURLWithPath: "/nonexistent-\(UUID().uuidString)/out.png")
        XCTAssertThrowsError(try ExportService.save(source, to: badURL))
    }

    /// Writes to the real system pasteboard, same as the app itself does on ⌘C — this
    /// mirrors production behavior rather than mocking it away.
    func test_copyToPasteboard_writesAReadableImage() {
        let source = makeSolidImage(width: 10, height: 10, color: .orange)
        ExportService.copyToPasteboard(source)
        XCTAssertTrue(NSPasteboard.general.canReadObject(forClasses: [NSImage.self], options: nil))
    }
}
