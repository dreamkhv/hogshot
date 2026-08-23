import AppKit
import ScreenCaptureKit

struct DisplayCapture {
    let screen: NSScreen
    let image: CGImage
}

enum ScreenCaptureError: Error {
    case noMatchingScreen
}

enum ScreenCaptureService {
    /// Captures a still image of every connected display. Each result is paired with
    /// the `NSScreen` it came from so the overlay can place one window per display.
    static func captureAllDisplays() async throws -> [DisplayCapture] {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        var results: [DisplayCapture] = []
        for display in content.displays {
            guard let screen = NSScreen.matching(displayID: display.displayID) else { continue }

            let filter = SCContentFilter(display: display, excludingWindows: [])
            let config = SCStreamConfiguration()
            let scale = screen.backingScaleFactor
            config.width = Int(CGFloat(display.width) * scale)
            config.height = Int(CGFloat(display.height) * scale)
            config.showsCursor = false
            config.captureResolution = .best

            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            results.append(DisplayCapture(screen: screen, image: image))
        }
        return results
    }
}

extension NSScreen {
    static func matching(displayID: CGDirectDisplayID) -> NSScreen? {
        screens.first { $0.displayID == displayID }
    }

    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}
