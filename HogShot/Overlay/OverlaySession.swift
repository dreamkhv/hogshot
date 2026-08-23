import AppKit

/// One capture-to-completion run: creates one `OverlayWindow` per display, shows them,
/// and tears everything down once the user finishes or cancels on any of them.
final class OverlaySession {
    private var windows: [OverlayWindow] = []
    private let onComplete: () -> Void

    init(captures: [DisplayCapture], onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
        windows = captures.map { capture in
            let view = OverlayView(capture: capture)
            let window = OverlayWindow(screen: capture.screen, contentView: view)
            view.delegate = self
            return window
        }
    }

    func present() {
        // The parameterless `activate()` can be deferred/ignored by the window server
        // when triggered from a background (LSUIElement) app that wasn't already
        // frontmost — exactly our case, since this always fires from a global hotkey.
        // When that happens the overlay window visually orders to the front but never
        // actually becomes key, so the very first click just finishes the activation
        // instead of starting a selection drag, and only the second click/drag works.
        // `ignoringOtherApps: true` forces activation synchronously, which this
        // hotkey-triggered, always-take-focus tool legitimately needs.
        NSApp.activate(ignoringOtherApps: true)
        for window in windows {
            window.orderFrontRegardless()
        }
        if let main = windows.first {
            main.makeKeyAndOrderFront(nil)
            main.makeFirstResponder(main.contentView)
        }
    }

    private func teardown() {
        for window in windows {
            window.orderOut(nil)
            window.contentView = nil
        }
        windows.removeAll()
        onComplete()
    }
}

extension OverlaySession: OverlayViewDelegate {
    func overlayView(_ view: OverlayView, didFinish action: OverlayView.CompletionAction, cropRect: CGRect, annotations: [Annotation]) {
        let capture = view.capture
        teardown()
        do {
            let image = try ExportService.flattenedImage(source: capture.image, cropRect: cropRect, annotations: annotations)
            switch action {
            case .copy: ExportService.copyToPasteboard(image)
            case .save: ExportService.promptSave(image)
            }
        } catch {
            NSSound.beep()
        }
    }

    func overlayViewDidCancel(_ view: OverlayView) {
        teardown()
    }
}
