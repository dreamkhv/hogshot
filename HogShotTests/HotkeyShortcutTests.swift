import XCTest
import Carbon.HIToolbox
import AppKit
@testable import HogShot

final class HotkeyShortcutTests: XCTestCase {

    func test_displayString_ordersModifiersControlOptionShiftCommand() {
        let shortcut = HotkeyShortcut(keyCode: UInt32(kVK_ANSI_A), modifiers: UInt32(cmdKey | shiftKey | optionKey | controlKey))
        XCTAssertEqual(shortcut.displayString, "⌃⌥⇧⌘A")
    }

    func test_displayString_withNoModifiers_isJustTheKey() {
        let shortcut = HotkeyShortcut(keyCode: UInt32(kVK_ANSI_A), modifiers: 0)
        XCTAssertEqual(shortcut.displayString, "A")
    }

    func test_displayString_forDefault_isCommandNine() {
        XCTAssertEqual(HotkeyShortcut.default.displayString, "⌘9")
    }

    func test_displayString_singleModifierVariants() {
        XCTAssertEqual(HotkeyShortcut(keyCode: UInt32(kVK_ANSI_A), modifiers: UInt32(controlKey)).displayString, "⌃A")
        XCTAssertEqual(HotkeyShortcut(keyCode: UInt32(kVK_ANSI_A), modifiers: UInt32(optionKey)).displayString, "⌥A")
        XCTAssertEqual(HotkeyShortcut(keyCode: UInt32(kVK_ANSI_A), modifiers: UInt32(shiftKey)).displayString, "⇧A")
        XCTAssertEqual(HotkeyShortcut(keyCode: UInt32(kVK_ANSI_A), modifiers: UInt32(cmdKey)).displayString, "⌘A")
    }

    func test_equatable_comparesBothFields() {
        let a = HotkeyShortcut(keyCode: 1, modifiers: 2)
        let b = HotkeyShortcut(keyCode: 1, modifiers: 2)
        let c = HotkeyShortcut(keyCode: 1, modifiers: 3)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    // MARK: - NSEvent.ModifierFlags.carbonFlags

    func test_carbonFlags_mapsEachCocoaModifierToItsCarbonEquivalent() {
        XCTAssertEqual(NSEvent.ModifierFlags.control.carbonFlags, UInt32(controlKey))
        XCTAssertEqual(NSEvent.ModifierFlags.option.carbonFlags, UInt32(optionKey))
        XCTAssertEqual(NSEvent.ModifierFlags.shift.carbonFlags, UInt32(shiftKey))
        XCTAssertEqual(NSEvent.ModifierFlags.command.carbonFlags, UInt32(cmdKey))
    }

    func test_carbonFlags_combinesMultipleModifiers() {
        let flags: NSEvent.ModifierFlags = [.command, .shift]
        XCTAssertEqual(flags.carbonFlags, UInt32(cmdKey | shiftKey))
    }

    func test_carbonFlags_ignoresIrrelevantFlags() {
        // .capsLock and .numericPad aren't part of any Carbon hotkey combination.
        let flags: NSEvent.ModifierFlags = [.control, .capsLock, .numericPad]
        XCTAssertEqual(flags.carbonFlags, UInt32(controlKey))
    }

    func test_carbonFlags_empty_isZero() {
        XCTAssertEqual(NSEvent.ModifierFlags().carbonFlags, 0)
    }

    // MARK: - HotkeyRecorder.capturedShortcut

    func test_capturedShortcut_requiresAtLeastOneModifier() {
        XCTAssertNil(HotkeyRecorder.capturedShortcut(forKeyDown: UInt16(kVK_ANSI_A), modifierFlags: []))
    }

    func test_capturedShortcut_withAModifier_succeeds() {
        let captured = HotkeyRecorder.capturedShortcut(forKeyDown: UInt16(kVK_ANSI_9), modifierFlags: .command)
        XCTAssertEqual(captured, HotkeyShortcut(keyCode: UInt32(kVK_ANSI_9), modifiers: UInt32(cmdKey)))
    }

    func test_capturedShortcut_ignoresIrrelevantModifiers_butKeepsRelevantOnes() {
        let captured = HotkeyRecorder.capturedShortcut(forKeyDown: UInt16(kVK_ANSI_A), modifierFlags: [.control, .capsLock])
        XCTAssertEqual(captured, HotkeyShortcut(keyCode: UInt32(kVK_ANSI_A), modifiers: UInt32(controlKey)))
    }

    func test_capturedShortcut_capsLockAlone_isRejected() {
        // capsLock isn't a usable hotkey modifier on its own — must still require
        // one of ⌃⌥⇧⌘ even though `modifierFlags` is technically non-empty.
        XCTAssertNil(HotkeyRecorder.capturedShortcut(forKeyDown: UInt16(kVK_ANSI_A), modifierFlags: .capsLock))
    }
}
