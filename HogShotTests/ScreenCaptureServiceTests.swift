import XCTest
import AppKit
import CoreGraphics
@testable import HogShot

final class ScreenCaptureServiceTests: XCTestCase {

    func test_displayID_isNonNilForRealScreens() throws {
        guard let main = NSScreen.main else { throw XCTSkip("no NSScreen.main in this environment") }
        XCTAssertNotNil(main.displayID)
    }

    func test_matching_returnsTheScreenOwningThatDisplayID() throws {
        guard let main = NSScreen.main, let id = main.displayID else {
            throw XCTSkip("no NSScreen.main / displayID in this environment")
        }
        XCTAssertEqual(NSScreen.matching(displayID: id), main)
    }

    func test_matching_returnsNilForAnUnknownDisplayID() {
        XCTAssertNil(NSScreen.matching(displayID: 0xFFFF_FFFF))
    }

    /// Exercises the real `ScreenCaptureKit` capture path end to end. Screen Recording
    /// permission can't be granted headlessly (it requires a one-time click through a
    /// system dialog), so this skips itself in environments where it isn't already
    /// granted rather than failing — but it's a real, meaningful check on any machine
    /// (including the developer's) where the app has already been authorized once.
    func test_captureAllDisplays_returnsOneNonEmptyCapturePerScreen() async throws {
        try XCTSkipUnless(CGPreflightScreenCaptureAccess(), "Screen Recording permission not granted in this environment")

        let captures = try await ScreenCaptureService.captureAllDisplays()

        XCTAssertEqual(captures.count, NSScreen.screens.count)
        for capture in captures {
            XCTAssertGreaterThan(capture.image.width, 0)
            XCTAssertGreaterThan(capture.image.height, 0)
        }
    }
}
