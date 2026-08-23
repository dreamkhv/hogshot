import Carbon.HIToolbox
import AppKit

/// A key + Carbon modifier-mask pair, exactly what `GlobalHotkey.init(keyCode:modifiers:)`
/// takes, plus a human-readable form for the settings UI.
struct HotkeyShortcut: Equatable {
    var keyCode: UInt32
    var modifiers: UInt32

    static let `default` = HotkeyShortcut(keyCode: UInt32(kVK_ANSI_9), modifiers: UInt32(cmdKey))

    /// e.g. "⌃⇧A". Resolves `keyCode` through the *current* keyboard layout (via
    /// `UCKeyTranslate`) rather than a hardcoded key-code table, so it shows whatever is
    /// actually printed on the key for non-QWERTY layouts too.
    var displayString: String {
        var result = ""
        if modifiers & UInt32(controlKey) != 0 { result += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { result += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { result += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { result += "⌘" }
        result += Self.character(forKeyCode: keyCode)
        return result
    }

    private static func character(forKeyCode keyCode: UInt32) -> String {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutDataPtr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else {
            return "?"
        }
        let layoutData = Unmanaged<CFData>.fromOpaque(layoutDataPtr).takeUnretainedValue() as Data
        return layoutData.withUnsafeBytes { rawBuffer -> String in
            guard let keyboardLayoutPtr = rawBuffer.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else {
                return "?"
            }
            var deadKeyState: UInt32 = 0
            var chars = [UniChar](repeating: 0, count: 4)
            var length = 0
            let status = UCKeyTranslate(
                keyboardLayoutPtr, UInt16(keyCode), UInt16(kUCKeyActionDisplay),
                0, UInt32(LMGetKbdType()), UInt32(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState, chars.count, &length, &chars
            )
            guard status == noErr, length > 0 else { return "?" }
            return String(utf16CodeUnits: chars, count: length).uppercased()
        }
    }
}

extension NSEvent.ModifierFlags {
    /// Maps the Cocoa modifier flags this app cares about to their Carbon equivalents
    /// (`controlKey`/`optionKey`/`shiftKey`/`cmdKey`), for handing off to `GlobalHotkey`.
    var carbonFlags: UInt32 {
        var flags: UInt32 = 0
        if contains(.control) { flags |= UInt32(controlKey) }
        if contains(.option) { flags |= UInt32(optionKey) }
        if contains(.shift) { flags |= UInt32(shiftKey) }
        if contains(.command) { flags |= UInt32(cmdKey) }
        return flags
    }
}
