import XCTest
import AppKit
@testable import HogShot

/// `OverlaySession.present()` orders real windows on screen, so it's deliberately not
/// exercised here. Its `OverlayViewDelegate` conformance — the crop/flatten/pasteboard
/// wiring that actually matters — doesn't depend on any window being shown, so it's
/// called directly instead.
final class OverlaySessionTests: XCTestCase {

    private func makeCapture(color: NSColor = .white, size: Int = 40) -> DisplayCapture {
        guard let screen = NSScreen.main else {
            fatalError("tests requiring NSScreen.main should XCTSkip before calling this")
        }
        return DisplayCapture(screen: screen, image: makeSolidImage(width: size, height: size, color: color))
    }

    func test_onFinishCopy_writesFlattenedImageToPasteboard_andCallsOnComplete() throws {
        guard NSScreen.main != nil else { throw XCTSkip("no NSScreen.main in this environment") }
        let capture = makeCapture()
        var completed = false
        let session = OverlaySession(captures: [capture]) { completed = true }
        let dummyView = OverlayView(capture: capture)

        NSPasteboard.general.clearContents()
        session.overlayView(dummyView, didFinish: .copy, cropRect: CGRect(x: 0, y: 0, width: 20, height: 20), annotations: [])

        XCTAssertTrue(completed, "onComplete must fire once the session finishes")
        XCTAssertTrue(NSPasteboard.general.canReadObject(forClasses: [NSImage.self], options: nil), "expected the flattened crop to land on the pasteboard")
    }

    func test_onFinishCopy_withInvalidCropRect_stillCallsOnComplete_withoutTouchingPasteboard() throws {
        guard NSScreen.main != nil else { throw XCTSkip("no NSScreen.main in this environment") }
        let capture = makeCapture()
        var completed = false
        let session = OverlaySession(captures: [capture]) { completed = true }
        let dummyView = OverlayView(capture: capture)

        NSPasteboard.general.clearContents()
        let marker = "sentinel-\(UUID().uuidString)"
        NSPasteboard.general.setString(marker, forType: .string)

        // Fully outside the capture's bounds -> ExportService.flattenedImage throws,
        // which OverlaySession swallows (beeps) without writing anything new.
        session.overlayView(dummyView, didFinish: .copy, cropRect: CGRect(x: 1000, y: 1000, width: 10, height: 10), annotations: [])

        XCTAssertTrue(completed, "onComplete must fire (teardown happens before export) even when export fails")
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), marker, "a failed export must not touch the pasteboard")
    }

    func test_onCancel_callsOnComplete_withoutTouchingPasteboard() throws {
        guard NSScreen.main != nil else { throw XCTSkip("no NSScreen.main in this environment") }
        let capture = makeCapture()
        var completed = false
        let session = OverlaySession(captures: [capture]) { completed = true }
        let dummyView = OverlayView(capture: capture)

        NSPasteboard.general.clearContents()
        let marker = "sentinel-\(UUID().uuidString)"
        NSPasteboard.general.setString(marker, forType: .string)

        session.overlayViewDidCancel(dummyView)

        XCTAssertTrue(completed)
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), marker, "cancelling must not touch the pasteboard")
    }
}
