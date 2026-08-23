import AppKit

/// Borderless window covering one full display, positioned above everything
/// (menu bar, Dock, other apps) so the frozen screenshot reads as "the screen itself".
///
/// This is an `NSPanel` with `.nonactivatingPanel`, not a plain `NSWindow`, on purpose:
/// when triggered from the global hotkey (as opposed to a click on our own menu bar
/// item, where the app is already active), macOS's documented behavior for a click that
/// lands on a non-key window is to spend that click bringing the window forward/key
/// *without* dispatching it as a real `mouseDown` — the crosshair cursor shows, but the
/// first drag does nothing, and only a second click/drag actually selects. A
/// `.nonactivatingPanel` is exempt from that "first click just activates" rule, so the
/// very first drag after the hotkey fires works.
final class OverlayWindow: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    init(screen: NSScreen, contentView: NSView) {
        super.init(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isReleasedWhenClosed = false
        // NSPanel defaults to hiding itself the instant the app resigns active; a plain
        // NSWindow has no such behavior, and this overlay must stay up regardless.
        hidesOnDeactivate = false
        self.contentView = contentView
        setFrame(screen.frame, display: true)
    }

    /// `.nonactivatingPanel` means becoming key does *not* automatically activate the
    /// app (that's the point — it's what lets the first click through). Restore normal
    /// activation explicitly once it does become key, so keyboard shortcuts and menu
    /// state behave as if this were a regular window.
    override func becomeKey() {
        NSApp.activate(ignoringOtherApps: true)
        super.becomeKey()
    }
}
