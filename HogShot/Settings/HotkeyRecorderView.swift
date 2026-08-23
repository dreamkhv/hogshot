import SwiftUI
import AppKit

/// Decides whether a captured key-down qualifies as a global-hotkey combination.
/// Pulled out of the view so it's testable without driving a real `NSEvent` monitor.
enum HotkeyRecorder {
    /// Esc cancels recording (handled by the caller before reaching here). Any other
    /// key needs at least one of ⌃⌥⇧⌘ — a bare letter key would be unusable (and
    /// dangerous) as a system-wide shortcut.
    static func capturedShortcut(forKeyDown keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags) -> HotkeyShortcut? {
        let relevant = modifierFlags.intersection([.command, .option, .control, .shift])
        guard !relevant.isEmpty else { return nil }
        return HotkeyShortcut(keyCode: UInt32(keyCode), modifiers: relevant.carbonFlags)
    }
}

/// A button that shows the current shortcut and, when clicked, records the next key
/// combination the user presses (via a local key-down monitor) as the new one.
struct HotkeyRecorderView: View {
    @Binding var shortcut: HotkeyShortcut
    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        Button {
            isRecording ? stopRecording() : startRecording()
        } label: {
            Text(isRecording ? String(localized: "Нажмите комбинацию…") : shortcut.displayString)
                .frame(minWidth: 120)
        }
        .onDisappear { stopRecording() }
    }

    private func startRecording() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // Esc cancels without changing anything
                stopRecording()
                return nil
            }
            if let captured = HotkeyRecorder.capturedShortcut(forKeyDown: event.keyCode, modifierFlags: event.modifierFlags) {
                shortcut = captured
                stopRecording()
            }
            return nil // swallow every key while recording, valid combo or not
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }
}
