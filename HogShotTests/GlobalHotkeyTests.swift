import XCTest
import Carbon.HIToolbox
@testable import HogShot

/// `GlobalHotkey` wraps the Carbon `RegisterEventHotKey` API, a real OS-level,
/// process-wide side effect. There's no way to headlessly simulate the OS delivering an
/// actual key-press to a Carbon hot key handler (that needs Accessibility/Input
/// Monitoring permissions and real HID event injection), so these tests deliberately
/// stick to what's reliably testable without touching real user input: registration
/// succeeding and cleanly unregistering. Uses obscure key/modifier combos unlikely to
/// collide with real shortcuts already bound on the machine running the tests.
final class GlobalHotkeyTests: XCTestCase {

    func test_init_succeedsForAPlausibleCombo() {
        var firedCount = 0
        let hotkey = GlobalHotkey(keyCode: UInt32(kVK_F18), modifiers: UInt32(controlKey | optionKey | shiftKey)) {
            firedCount += 1
        }
        XCTAssertNotNil(hotkey)
        _ = firedCount // registered but never fired in this headless test
    }

    func test_multipleDistinctRegistrations_allSucceedIndependently() {
        let first = GlobalHotkey(keyCode: UInt32(kVK_F18), modifiers: UInt32(controlKey | optionKey)) {}
        let second = GlobalHotkey(keyCode: UInt32(kVK_F19), modifiers: UInt32(controlKey | optionKey)) {}
        XCTAssertNotNil(first)
        XCTAssertNotNil(second)
    }

    func test_deinit_unregistersWithoutCrashing() {
        autoreleasepool {
            let hotkey = GlobalHotkey(keyCode: UInt32(kVK_F18), modifiers: UInt32(controlKey | shiftKey | optionKey)) {}
            XCTAssertNotNil(hotkey)
        }
        // Reaching this line without a crash/hang is the assertion: `deinit` ran and
        // called `UnregisterEventHotKey` cleanly.
    }
}
