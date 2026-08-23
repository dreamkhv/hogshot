import XCTest
import AppKit
@testable import HogShot

final class PreferencesTests: XCTestCase {
    private let suiteName = "com.untitledproject.tests.preferences"
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    func test_freshInstance_withNothingPersisted_usesDocumentedDefaults() {
        let prefs = Preferences(defaults: defaults)
        XCTAssertEqual(prefs.postCaptureAction, .copyToClipboard)
        XCTAssertEqual(prefs.defaultLineWidth, 4)
        XCTAssertEqual(prefs.appLanguage, .system)
        XCTAssertEqual(prefs.hotkeyShortcut, .default)
        assertColorsEqual(prefs.defaultColor, .systemRed)
    }

    func test_hotkeyShortcut_persistsAcrossInstances() {
        let first = Preferences(defaults: defaults)
        first.hotkeyShortcut = HotkeyShortcut(keyCode: 42, modifiers: 99)
        XCTAssertEqual(defaults.integer(forKey: Preferences.Keys.hotkeyKeyCode), 42)
        XCTAssertEqual(defaults.integer(forKey: Preferences.Keys.hotkeyModifiers), 99)

        let second = Preferences(defaults: defaults)
        XCTAssertEqual(second.hotkeyShortcut, HotkeyShortcut(keyCode: 42, modifiers: 99))
    }

    func test_hotkeyShortcut_setterUpdatesBothUnderlyingFields() {
        let prefs = Preferences(defaults: defaults)
        prefs.hotkeyShortcut = HotkeyShortcut(keyCode: 7, modifiers: 3)
        XCTAssertEqual(prefs.hotkeyKeyCode, 7)
        XCTAssertEqual(prefs.hotkeyModifiers, 3)
    }

    func test_postCaptureAction_persistsAcrossInstances() {
        let first = Preferences(defaults: defaults)
        first.postCaptureAction = .openSavePanel
        XCTAssertEqual(defaults.string(forKey: Preferences.Keys.postCaptureAction), PostCaptureAction.openSavePanel.rawValue)

        let second = Preferences(defaults: defaults)
        XCTAssertEqual(second.postCaptureAction, .openSavePanel)
    }

    func test_defaultLineWidth_persistsAcrossInstances() {
        let first = Preferences(defaults: defaults)
        first.defaultLineWidth = 9
        XCTAssertEqual(defaults.double(forKey: Preferences.Keys.defaultLineWidth), 9)

        let second = Preferences(defaults: defaults)
        XCTAssertEqual(second.defaultLineWidth, 9)
    }

    func test_defaultColor_persistsAcrossInstances() {
        let first = Preferences(defaults: defaults)
        first.defaultColor = .systemBlue
        XCTAssertNotNil(defaults.data(forKey: Preferences.Keys.defaultColor))

        let second = Preferences(defaults: defaults)
        assertColorsEqual(second.defaultColor, .systemBlue)
    }

    func test_appLanguage_persistsAcrossInstances() {
        let first = Preferences(defaults: defaults)
        first.appLanguage = .english
        XCTAssertEqual(defaults.string(forKey: Preferences.Keys.appLanguage), AppLanguage.english.rawValue)

        let second = Preferences(defaults: defaults)
        XCTAssertEqual(second.appLanguage, .english)
    }

    func test_appLanguage_nonSystemValue_setsAppleLanguagesOverride() {
        let prefs = Preferences(defaults: defaults)

        prefs.appLanguage = .english
        XCTAssertEqual(defaults.stringArray(forKey: "AppleLanguages"), ["en"])

        prefs.appLanguage = .russian
        XCTAssertEqual(defaults.stringArray(forKey: "AppleLanguages"), ["ru"])
    }

    func test_appLanguage_backToSystem_removesAppleLanguagesOverride() {
        // `AppleLanguages` also exists in the global domain (the OS's own language
        // list), which every UserDefaults instance falls back to — so a plain
        // `stringArray(forKey:)` lookup would still find *something* even after our
        // suite's own override is removed. Inspect this suite's persistent domain
        // directly to check what *we* actually stored, bypassing that fallback.
        func ourOwnOverride() -> [String]? {
            defaults.persistentDomain(forName: suiteName)?["AppleLanguages"] as? [String]
        }

        let prefs = Preferences(defaults: defaults)
        prefs.appLanguage = .english
        XCTAssertEqual(ourOwnOverride(), ["en"])

        prefs.appLanguage = .system
        XCTAssertNil(ourOwnOverride(), "switching back to 'system' must defer to the OS again, not pin a stale override")
    }

    func test_invalidPersistedAppLanguage_fallsBackToDefault() {
        defaults.set("klingon", forKey: Preferences.Keys.appLanguage)
        let prefs = Preferences(defaults: defaults)
        XCTAssertEqual(prefs.appLanguage, .system)
    }

    func test_invalidPersistedPostCaptureAction_fallsBackToDefault() {
        defaults.set("not-a-real-raw-value", forKey: Preferences.Keys.postCaptureAction)
        let prefs = Preferences(defaults: defaults)
        XCTAssertEqual(prefs.postCaptureAction, .copyToClipboard)
    }

    func test_corruptedColorData_fallsBackToDefault() {
        defaults.set(Data([0, 1, 2, 3]), forKey: Preferences.Keys.defaultColor)
        let prefs = Preferences(defaults: defaults)
        assertColorsEqual(prefs.defaultColor, .systemRed)
    }

    func test_instancesWithDifferentSuites_areIndependent() {
        let otherSuiteName = suiteName + ".other"
        let otherDefaults = UserDefaults(suiteName: otherSuiteName)!
        otherDefaults.removePersistentDomain(forName: otherSuiteName)
        defer { otherDefaults.removePersistentDomain(forName: otherSuiteName) }

        let a = Preferences(defaults: defaults)
        let b = Preferences(defaults: otherDefaults)
        a.defaultLineWidth = 11
        XCTAssertEqual(b.defaultLineWidth, 4, "a separate UserDefaults suite must not see the other instance's writes")
    }

    private func assertColorsEqual(_ a: NSColor, _ b: NSColor, accuracy: CGFloat = 0.01, file: StaticString = #filePath, line: UInt = #line) {
        guard let ca = a.usingColorSpace(.deviceRGB), let cb = b.usingColorSpace(.deviceRGB) else {
            return XCTFail("could not convert colors to a comparable color space", file: file, line: line)
        }
        XCTAssertEqual(ca.redComponent, cb.redComponent, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(ca.greenComponent, cb.greenComponent, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(ca.blueComponent, cb.blueComponent, accuracy: accuracy, file: file, line: line)
    }
}
