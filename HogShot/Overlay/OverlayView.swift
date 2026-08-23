import AppKit
import SwiftUI

protocol OverlayViewDelegate: AnyObject {
    func overlayView(_ view: OverlayView, didFinish action: OverlayView.CompletionAction, cropRect: CGRect, annotations: [Annotation])
    func overlayViewDidCancel(_ view: OverlayView)
}

/// One borderless full-screen view per display. Owns the whole capture interaction:
/// dragging out a selection, resizing/moving it, drawing annotations on top, and the
/// keyboard shortcuts that finish or cancel the session.
final class OverlayView: NSView, NSTextFieldDelegate {
    enum CompletionAction { case copy, save }

    private enum DragMode {
        case creatingSelection(startPixel: CGPoint)
        case movingSelection(originalRect: CGRect, mouseDownPixel: CGPoint)
        case resizingSelection(handle: ResizeHandle, originalRect: CGRect, mouseDownPixel: CGPoint)
        case drawingAnnotation
    }

    weak var delegate: OverlayViewDelegate?
    let capture: DisplayCapture

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    /// Image pixels per view point. Annotation/selection state lives in pixel space;
    /// this is the only place that scale is applied.
    private let pixelScale: CGFloat

    private var selection: CGRect?
    private var annotations: [Annotation] = []
    private var redoStack: [Annotation] = []
    // Not private: lets tests select a tool programmatically without driving the
    // SwiftUI toolbar UI, the way a user's click on it would.
    var currentTool: AnnotationTool?
    private var toolColor: NSColor
    private let toolLineWidth: CGFloat

    private var dragMode: DragMode?
    private var inProgressAnnotation: Annotation?

    private var activeTextField: NSTextField?
    private var textFieldOrigin: CGPoint?

    private var toolbarHost: NSHostingView<OverlayToolbarView>?

    init(capture: DisplayCapture) {
        self.capture = capture
        self.pixelScale = CGFloat(capture.image.width) / capture.screen.frame.width
        self.toolColor = Preferences.shared.defaultColor
        self.toolLineWidth = CGFloat(Preferences.shared.defaultLineWidth)
        super.init(frame: CGRect(origin: .zero, size: capture.screen.frame.size))
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    // MARK: - Coordinate conversion

    private func pixelPoint(from event: NSEvent) -> CGPoint {
        let viewPoint = convert(event.locationInWindow, from: nil)
        return CGPoint(x: viewPoint.x * pixelScale, y: viewPoint.y * pixelScale)
    }

    private func viewRect(fromPixels rect: CGRect) -> CGRect {
        CGRect(x: rect.origin.x / pixelScale, y: rect.origin.y / pixelScale,
               width: rect.width / pixelScale, height: rect.height / pixelScale)
    }

    private func clampToImageBounds(_ rect: CGRect) -> CGRect {
        let bounds = CGRect(x: 0, y: 0, width: CGFloat(capture.image.width), height: CGFloat(capture.image.height))
        var r = rect
        if r.width > bounds.width { r.size.width = bounds.width }
        if r.height > bounds.height { r.size.height = bounds.height }
        if r.minX < bounds.minX { r.origin.x = bounds.minX }
        if r.minY < bounds.minY { r.origin.y = bounds.minY }
        if r.maxX > bounds.maxX { r.origin.x = bounds.maxX - r.width }
        if r.maxY > bounds.maxY { r.origin.y = bounds.maxY - r.height }
        return r
    }

    private func resizeHandle(at point: CGPoint, in selection: CGRect) -> ResizeHandle? {
        let tolerance = 8 * pixelScale
        return ResizeHandle.allCases.first { handle in
            let p = handle.point(in: selection)
            return abs(p.x - point.x) <= tolerance && abs(p.y - point.y) <= tolerance
        }
    }

    // MARK: - Mouse

    override func mouseDown(with event: NSEvent) {
        endTextEditing(commit: true)
        let point = pixelPoint(from: event)

        if let tool = currentTool, selection != nil {
            if tool == .text {
                beginTextEntry(at: point)
                return
            }
            inProgressAnnotation = Annotation(tool: tool, points: [point], color: toolColor, lineWidth: toolLineWidth)
            dragMode = .drawingAnnotation
            return
        }

        if let selection {
            if let handle = resizeHandle(at: point, in: selection) {
                dragMode = .resizingSelection(handle: handle, originalRect: selection, mouseDownPixel: point)
                return
            }
            if selection.contains(point) {
                dragMode = .movingSelection(originalRect: selection, mouseDownPixel: point)
                return
            }
        }

        selection = nil
        annotations.removeAll()
        redoStack.removeAll()
        hideToolbar()
        dragMode = .creatingSelection(startPixel: point)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let dragMode else { return }
        let point = pixelPoint(from: event)

        switch dragMode {
        case .creatingSelection(let start):
            selection = CGRect(corner: start, opposite: point)
        case .movingSelection(let originalRect, let mouseDownPixel):
            let delta = CGPoint(x: point.x - mouseDownPixel.x, y: point.y - mouseDownPixel.y)
            selection = clampToImageBounds(originalRect.offsetBy(dx: delta.x, dy: delta.y))
        case .resizingSelection(let handle, let originalRect, let mouseDownPixel):
            let delta = CGPoint(x: point.x - mouseDownPixel.x, y: point.y - mouseDownPixel.y)
            selection = handle.applying(delta: delta, to: originalRect)
        case .drawingAnnotation:
            inProgressAnnotation?.points.append(point)
        }
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        defer { dragMode = nil }
        guard let dragMode else { return }

        switch dragMode {
        case .creatingSelection:
            if let selection, selection.width > 4, selection.height > 4 {
                self.selection = selection.standardized
            } else {
                self.selection = nil
            }
        case .movingSelection, .resizingSelection:
            break
        case .drawingAnnotation:
            if let annotation = inProgressAnnotation, annotation.points.count >= 2 {
                annotations.append(annotation)
                redoStack.removeAll()
            }
            inProgressAnnotation = nil
        }

        if selection != nil {
            syncToolbar()
        } else {
            hideToolbar()
        }
        needsDisplay = true
    }

    // MARK: - Keyboard

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Esc
            cancel()
            return
        }
        if event.specialKey == .some(.enter) || event.specialKey == .some(.carriageReturn) {
            if selection != nil {
                finish(Preferences.shared.postCaptureAction == .openSavePanel ? .save : .copy)
            }
            return
        }

        guard let chars = event.charactersIgnoringModifiers, event.modifierFlags.contains(.command) else {
            super.keyDown(with: event)
            return
        }
        switch chars {
        case "c" where selection != nil: finish(.copy)
        case "s" where selection != nil: finish(.save)
        case "z" where event.modifierFlags.contains(.shift): redo()
        case "z": undo()
        default: super.keyDown(with: event)
        }
    }

    // MARK: - Text tool

    private func beginTextEntry(at pixelPoint: CGPoint) {
        let origin = viewRect(fromPixels: CGRect(origin: pixelPoint, size: .zero)).origin
        let field = NSTextField(frame: CGRect(x: origin.x, y: origin.y, width: 240, height: 30))
        field.font = .systemFont(ofSize: 20, weight: .semibold)
        field.textColor = toolColor
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.delegate = self
        addSubview(field)
        window?.makeFirstResponder(field)
        activeTextField = field
        textFieldOrigin = pixelPoint
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            endTextEditing(commit: true)
            return true
        }
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            endTextEditing(commit: false)
            return true
        }
        return false
    }

    private func endTextEditing(commit: Bool) {
        guard let field = activeTextField, let origin = textFieldOrigin else { return }
        let text = field.stringValue
        field.removeFromSuperview()
        activeTextField = nil
        textFieldOrigin = nil
        window?.makeFirstResponder(self)

        if commit, !text.isEmpty {
            let annotation = Annotation(tool: .text, points: [origin], color: toolColor, lineWidth: toolLineWidth, text: text, fontSize: 22)
            annotations.append(annotation)
            redoStack.removeAll()
            syncToolbar()
            needsDisplay = true
        }
    }

    // MARK: - Undo / redo

    private func undo() {
        guard let last = annotations.popLast() else { return }
        redoStack.append(last)
        syncToolbar()
        needsDisplay = true
    }

    private func redo() {
        guard let last = redoStack.popLast() else { return }
        annotations.append(last)
        syncToolbar()
        needsDisplay = true
    }

    // MARK: - Toolbar

    private func syncToolbar() {
        guard let selection else { return }
        if let host = toolbarHost {
            host.rootView = makeToolbarView()
        } else {
            let host = NSHostingView(rootView: makeToolbarView())
            addSubview(host)
            toolbarHost = host
        }
        positionToolbar(near: viewRect(fromPixels: selection))
    }

    private func hideToolbar() {
        toolbarHost?.removeFromSuperview()
        toolbarHost = nil
    }

    private func positionToolbar(near selectionInView: CGRect) {
        guard let host = toolbarHost else { return }
        let size = host.fittingSize
        var origin = CGPoint(x: selectionInView.minX, y: selectionInView.minY - size.height - 8)
        if origin.y < 0 {
            origin.y = selectionInView.maxY + 8
        }
        origin.x = min(max(0, origin.x), max(0, bounds.width - size.width))
        host.frame = CGRect(origin: origin, size: size)
    }

    private func makeToolbarView() -> OverlayToolbarView {
        OverlayToolbarView(
            selectedTool: Binding(
                get: { [weak self] in self?.currentTool },
                set: { [weak self] newValue in self?.currentTool = newValue }
            ),
            color: Binding(
                get: { [weak self] in Color(nsColor: self?.toolColor ?? .systemRed) },
                set: { [weak self] newValue in self?.toolColor = NSColor(newValue) }
            ),
            canUndo: !annotations.isEmpty,
            canRedo: !redoStack.isEmpty,
            onUndo: { [weak self] in self?.undo() },
            onRedo: { [weak self] in self?.redo() },
            onCopy: { [weak self] in self?.finish(.copy) },
            onSave: { [weak self] in self?.finish(.save) },
            onCancel: { [weak self] in self?.cancel() }
        )
    }

    // MARK: - Finishing

    private func finish(_ action: CompletionAction) {
        endTextEditing(commit: true)
        guard let selection else { return }
        delegate?.overlayView(self, didFinish: action, cropRect: selection, annotations: annotations)
    }

    private func cancel() {
        if activeTextField != nil {
            endTextEditing(commit: false)
            return
        }
        delegate?.overlayViewDidCancel(self)
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        // `NSImage(cgImage:).draw(in:)` does not compensate for `isFlipped` views the
        // way ordinary NSImage draws do, so it renders the screenshot upside down here.
        // Route it through the same right-side-up helper used for every other raw
        // `CGImage` draw in this app (see AnnotationRenderer's coordinate-space contract).
        AnnotationRenderer.drawImageRightSideUp(capture.image, in: bounds, ctx: ctx)

        let selectionInView = selection.map(viewRect(fromPixels:))

        ctx.saveGState()
        ctx.setFillColor(NSColor.black.withAlphaComponent(0.45).cgColor)
        if let selectionInView {
            let path = CGMutablePath()
            path.addRect(bounds)
            path.addRect(selectionInView)
            ctx.addPath(path)
            ctx.fillPath(using: .evenOdd)
        } else {
            ctx.fill(bounds)
        }
        ctx.restoreGState()

        guard let selection, let selectionInView else { return }

        ctx.saveGState()
        ctx.scaleBy(x: 1 / pixelScale, y: 1 / pixelScale)
        var allAnnotations = annotations
        if let inProgressAnnotation { allAnnotations.append(inProgressAnnotation) }
        AnnotationRenderer.draw(allAnnotations, into: ctx, source: capture.image)
        ctx.restoreGState()

        ctx.setStrokeColor(NSColor.white.cgColor)
        ctx.setLineWidth(1.5)
        ctx.stroke(selectionInView)

        ctx.setFillColor(NSColor.white.cgColor)
        for handle in ResizeHandle.allCases {
            let p = handle.point(in: selectionInView)
            ctx.fillEllipse(in: CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8))
        }

        drawSizeLabel(pixelSize: selection.size, at: selectionInView)
    }

    private func drawSizeLabel(pixelSize: CGSize, at selectionInView: CGRect) {
        let text = "\(Int(pixelSize.width)) × \(Int(pixelSize.height))"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white,
        ]
        let size = (text as NSString).size(withAttributes: attributes)
        let labelOrigin = CGPoint(x: selectionInView.minX, y: max(0, selectionInView.minY - size.height - 6))
        let background = CGRect(origin: labelOrigin, size: CGSize(width: size.width + 10, height: size.height + 4))

        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setFillColor(NSColor.black.withAlphaComponent(0.6).cgColor)
        ctx.fill(background)
        (text as NSString).draw(at: CGPoint(x: labelOrigin.x + 5, y: labelOrigin.y + 2), withAttributes: attributes)
    }
}

private extension CGRect {
    init(corner: CGPoint, opposite: CGPoint) {
        self.init(
            x: min(corner.x, opposite.x),
            y: min(corner.y, opposite.y),
            width: abs(corner.x - opposite.x),
            height: abs(corner.y - opposite.y)
        )
    }
}
