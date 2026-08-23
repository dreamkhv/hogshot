import XCTest
import AppKit
@testable import HogShot

/// Drives `OverlayView` the same way real mouse/keyboard input would: by constructing
/// synthetic `NSEvent`s and calling the view's own `mouseDown`/`mouseDragged`/
/// `mouseUp`/`keyDown` overrides directly. The view is hosted in a real (never shown)
/// `NSWindow` purely so `convert(_:from:)` has a window to resolve coordinates against —
/// nothing is ever ordered on screen.
final class OverlayViewTests: XCTestCase {

    private final class SpyDelegate: OverlayViewDelegate {
        private(set) var finishCalls: [(action: OverlayView.CompletionAction, cropRect: CGRect, annotations: [Annotation])] = []
        private(set) var cancelCallCount = 0

        func overlayView(_ view: OverlayView, didFinish action: OverlayView.CompletionAction, cropRect: CGRect, annotations: [Annotation]) {
            finishCalls.append((action, cropRect, annotations))
        }
        func overlayViewDidCancel(_ view: OverlayView) {
            cancelCallCount += 1
        }
    }

    private var screen: NSScreen!
    private var window: NSWindow!
    private var view: OverlayView!
    private var delegate: SpyDelegate!

    override func setUpWithError() throws {
        try super.setUpWithError()
        guard let mainScreen = NSScreen.main else {
            throw XCTSkip("No NSScreen.main available in this environment")
        }
        screen = mainScreen

        // pixelScale == image.width / screen.frame.width; sizing the fixture image to
        // exactly the screen's point size makes pixelScale == 1, so pixel space and
        // view-point space coincide and test coordinates need no scale conversion.
        let width = Int(screen.frame.width)
        let height = Int(screen.frame.height)
        let image = makeSolidImage(width: width, height: height, color: .white)
        let capture = DisplayCapture(screen: screen, image: image)

        window = NSWindow(contentRect: CGRect(origin: .zero, size: screen.frame.size),
                           styleMask: [.borderless], backing: .buffered, defer: false)
        view = OverlayView(capture: capture)
        window.contentView = view

        delegate = SpyDelegate()
        view.delegate = delegate
    }

    override func tearDown() {
        view = nil
        window = nil
        delegate = nil
        screen = nil
        super.tearDown()
    }

    // MARK: - event helpers

    private func mouseEvent(_ type: NSEvent.EventType, at viewPoint: CGPoint) -> NSEvent {
        let windowPoint = view.convert(NSPoint(x: viewPoint.x, y: viewPoint.y), to: nil)
        return NSEvent.mouseEvent(
            with: type, location: windowPoint, modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
            context: nil, eventNumber: 0, clickCount: 1, pressure: 1
        )!
    }

    private func drag(from start: CGPoint, to end: CGPoint) {
        view.mouseDown(with: mouseEvent(.leftMouseDown, at: start))
        view.mouseDragged(with: mouseEvent(.leftMouseDragged, at: end))
        view.mouseUp(with: mouseEvent(.leftMouseUp, at: end))
    }

    private func keyEvent(chars: String, modifiers: NSEvent.ModifierFlags, keyCode: UInt16 = 0) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: modifiers,
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
            context: nil, characters: chars, charactersIgnoringModifiers: chars,
            isARepeat: false, keyCode: keyCode
        )!
    }

    private func pressCommand(_ char: String) {
        view.keyDown(with: keyEvent(chars: char, modifiers: .command))
    }

    private func pressCommandShift(_ char: String) {
        view.keyDown(with: keyEvent(chars: char, modifiers: [.command, .shift]))
    }

    private func pressEsc() {
        view.keyDown(with: keyEvent(chars: "\u{1b}", modifiers: [], keyCode: 53))
    }

    // MARK: - the orientation bug this app actually shipped

    /// Direct regression test for the "screenshot renders upside down in the overlay"
    /// bug: `OverlayView.draw(_:)` must show the captured screenshot in the same visual
    /// orientation it was captured in.
    func test_draw_rendersScreenshotRightSideUp() {
        let width = Int(screen.frame.width)
        let height = Int(screen.frame.height)
        let topBottomImage = makeTopBottomImage(width: width, height: height, top: .red, bottom: .blue)
        let orientedView = OverlayView(capture: DisplayCapture(screen: screen, image: topBottomImage))
        orientedView.setFrameSize(NSSize(width: width, height: height))

        guard let rep = orientedView.bitmapImageRepForCachingDisplay(in: orientedView.bounds) else {
            return XCTFail("could not create a bitmap rep for the view")
        }
        orientedView.cacheDisplay(in: orientedView.bounds, to: rep)
        guard let rendered = rep.cgImage else { return XCTFail("cacheDisplay produced no image") }

        let top = pixel(of: rendered, x: rep.pixelsWide / 2, y: 2)
        let bottom = pixel(of: rendered, x: rep.pixelsWide / 2, y: rep.pixelsHigh - 3)
        // The real screen's color profile dilutes raw NSColor.red/.blue during
        // cacheDisplay, so compare channel dominance rather than an absolute magnitude.
        XCTAssertGreaterThan(top.r, top.b, "expected the top of the rendered overlay to read redder than blue, got \(top)")
        XCTAssertGreaterThan(bottom.b, bottom.r, "expected the bottom of the rendered overlay to read bluer than red, got \(bottom)")
    }

    // MARK: - selection

    func test_drag_createsSelection_reportedOnFinish() {
        drag(from: CGPoint(x: 50, y: 50), to: CGPoint(x: 200, y: 150))
        pressCommand("c")

        XCTAssertEqual(delegate.finishCalls.count, 1)
        guard let call = delegate.finishCalls.first else { return }
        XCTAssertEqual(call.action, .copy)
        XCTAssertEqual(call.cropRect, CGRect(x: 50, y: 50, width: 150, height: 100))
        XCTAssertTrue(call.annotations.isEmpty)
    }

    func test_tinyDrag_isDiscardedAsNoSelection() {
        drag(from: CGPoint(x: 50, y: 50), to: CGPoint(x: 52, y: 52))
        pressCommand("c")
        XCTAssertEqual(delegate.finishCalls.count, 0, "a 2x2px drag is below the minimum selection size and should be discarded")
    }

    func test_finish_withoutAnySelection_doesNothing() {
        pressCommand("c")
        XCTAssertEqual(delegate.finishCalls.count, 0)
    }

    func test_escBeforeSelection_cancels() {
        pressEsc()
        XCTAssertEqual(delegate.cancelCallCount, 1)
    }

    func test_escAfterSelection_cancels() {
        drag(from: CGPoint(x: 50, y: 50), to: CGPoint(x: 200, y: 150))
        pressEsc()
        XCTAssertEqual(delegate.cancelCallCount, 1)
        XCTAssertEqual(delegate.finishCalls.count, 0)
    }

    func test_resizeHandleDrag_adjustsSelectionBeforeFinish() {
        drag(from: CGPoint(x: 100, y: 100), to: CGPoint(x: 400, y: 300)) // -> (100,100,300,200)
        drag(from: CGPoint(x: 400, y: 300), to: CGPoint(x: 430, y: 320)) // drag the bottomRight handle
        pressCommand("c")

        XCTAssertEqual(delegate.finishCalls.count, 1)
        XCTAssertEqual(delegate.finishCalls.first?.cropRect, CGRect(x: 100, y: 100, width: 330, height: 220))
    }

    func test_dragInsideSelection_movesItRatherThanResizing() {
        drag(from: CGPoint(x: 100, y: 100), to: CGPoint(x: 400, y: 300)) // -> (100,100,300,200)
        drag(from: CGPoint(x: 250, y: 200), to: CGPoint(x: 270, y: 210)) // interior point, delta (20,10)
        pressCommand("c")

        XCTAssertEqual(delegate.finishCalls.count, 1)
        XCTAssertEqual(delegate.finishCalls.first?.cropRect, CGRect(x: 120, y: 110, width: 300, height: 200))
    }

    func test_dragOutsideExistingSelection_replacesItWithANewOne() {
        drag(from: CGPoint(x: 100, y: 100), to: CGPoint(x: 400, y: 300))
        drag(from: CGPoint(x: 700, y: 700), to: CGPoint(x: 800, y: 780)) // well outside the first selection
        pressCommand("c")

        XCTAssertEqual(delegate.finishCalls.count, 1)
        XCTAssertEqual(delegate.finishCalls.first?.cropRect, CGRect(x: 700, y: 700, width: 100, height: 80))
    }

    // MARK: - annotations, undo/redo

    func test_penAnnotation_isIncludedOnFinish() {
        drag(from: CGPoint(x: 50, y: 50), to: CGPoint(x: 350, y: 350))
        view.currentTool = .pen
        drag(from: CGPoint(x: 100, y: 100), to: CGPoint(x: 150, y: 160))
        pressCommand("c")

        XCTAssertEqual(delegate.finishCalls.count, 1)
        let annotations = delegate.finishCalls[0].annotations
        XCTAssertEqual(annotations.count, 1)
        XCTAssertEqual(annotations.first?.tool, .pen)
        XCTAssertEqual(annotations.first?.points.count, 2)
    }

    func test_annotationWithoutDrag_isNotAdded() {
        drag(from: CGPoint(x: 50, y: 50), to: CGPoint(x: 350, y: 350))
        view.currentTool = .pen
        // mouseDown + mouseUp at the same point, no mouseDragged in between: only one point recorded.
        view.mouseDown(with: mouseEvent(.leftMouseDown, at: CGPoint(x: 100, y: 100)))
        view.mouseUp(with: mouseEvent(.leftMouseUp, at: CGPoint(x: 100, y: 100)))
        pressCommand("c")

        XCTAssertTrue(delegate.finishCalls.first?.annotations.isEmpty ?? false, "a single-point annotation (no drag) must be discarded")
    }

    func test_undo_removesMostRecentAnnotation() {
        drag(from: CGPoint(x: 50, y: 50), to: CGPoint(x: 350, y: 350))
        view.currentTool = .pen
        drag(from: CGPoint(x: 100, y: 100), to: CGPoint(x: 120, y: 130))
        drag(from: CGPoint(x: 150, y: 150), to: CGPoint(x: 170, y: 180))

        pressCommand("z")
        pressCommand("c")

        XCTAssertEqual(delegate.finishCalls.first?.annotations.count, 1)
    }

    func test_redo_restoresUndoneAnnotation() {
        drag(from: CGPoint(x: 50, y: 50), to: CGPoint(x: 350, y: 350))
        view.currentTool = .pen
        drag(from: CGPoint(x: 100, y: 100), to: CGPoint(x: 120, y: 130))
        drag(from: CGPoint(x: 150, y: 150), to: CGPoint(x: 170, y: 180))

        pressCommand("z")
        pressCommandShift("z")
        pressCommand("c")

        XCTAssertEqual(delegate.finishCalls.first?.annotations.count, 2)
    }

    func test_newAnnotationAfterUndo_clearsTheRedoStack() {
        drag(from: CGPoint(x: 50, y: 50), to: CGPoint(x: 350, y: 350))
        view.currentTool = .pen
        drag(from: CGPoint(x: 100, y: 100), to: CGPoint(x: 120, y: 130))
        pressCommand("z") // annotations: [], redoStack: [first]

        drag(from: CGPoint(x: 200, y: 200), to: CGPoint(x: 220, y: 230)) // new annotation should drop the old redo entry
        pressCommandShift("z") // redo should now be a no-op
        pressCommand("c")

        XCTAssertEqual(delegate.finishCalls.first?.annotations.count, 1)
    }

    func test_undoWithNoAnnotations_doesNothing() {
        drag(from: CGPoint(x: 50, y: 50), to: CGPoint(x: 350, y: 350))
        pressCommand("z") // no annotations to undo; must not crash or misbehave
        pressCommand("c")
        XCTAssertEqual(delegate.finishCalls.first?.annotations.count, 0)
    }
}
