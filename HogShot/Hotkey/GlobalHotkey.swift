import Carbon.HIToolbox
import AppKit

/// Registers a system-wide keyboard shortcut via the classic Carbon Hot Key API.
///
/// This is a deliberate choice over `NSEvent.addGlobalMonitorForEvents`: Carbon hotkeys
/// fire even when the app has no key window and, crucially, don't require Accessibility
/// permission — only the shortcut itself is granted to us, nothing else.
final class GlobalHotkey {
    fileprivate static var registry: [UInt32: () -> Void] = [:]
    private static var eventHandlerRef: EventHandlerRef?
    private static var nextID: UInt32 = 1

    private let id: UInt32
    private var hotKeyRef: EventHotKeyRef?

    /// - Parameters:
    ///   - keyCode: a `kVK_*` virtual key code from `Carbon.HIToolbox`.
    ///   - modifiers: a combination of `controlKey`, `shiftKey`, `optionKey`, `cmdKey`.
    init?(keyCode: UInt32, modifiers: UInt32, onPress: @escaping () -> Void) {
        Self.installHandlerIfNeeded()

        let id = Self.nextID
        Self.nextID += 1
        self.id = id

        // "MSHK" as a four-char OSType signature, arbitrary but namespaced to this app.
        let signature: OSType = 0x4D53484B
        let hotKeyID = EventHotKeyID(signature: signature, id: id)

        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        guard status == noErr else { return nil }

        Self.registry[id] = onPress
    }

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        Self.registry[id] = nil
    }

    private static func installHandlerIfNeeded() {
        guard eventHandlerRef == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), globalHotKeyHandler, 1, &eventType, nil, &eventHandlerRef)
    }
}

private func globalHotKeyHandler(nextHandler: EventHandlerCallRef?, event: EventRef?, userData: UnsafeMutableRawPointer?) -> OSStatus {
    if let event {
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
            nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID
        )
        if status == noErr {
            GlobalHotkey.registry[hotKeyID.id]?()
        }
    }
    return CallNextEventHandler(nextHandler, event)
}
