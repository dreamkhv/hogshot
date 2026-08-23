import AppKit
import Combine

enum PostCaptureAction: String, CaseIterable, Identifiable {
    case copyToClipboard
    case openSavePanel

    var id: String { rawValue }

    var label: String {
        switch self {
        case .copyToClipboard: String(localized: "Копировать в буфер обмена")
        case .openSavePanel: String(localized: "Открыть диалог сохранения")
        }
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case russian
    case english

    var id: String { rawValue }

    /// Language names are shown in their own language regardless of the current UI
    /// language — the usual convention for a language picker — so only "system" is
    /// actually localized here.
    var label: String {
        switch self {
        case .system: String(localized: "Как в системе")
        case .russian: "Русский"
        case .english: "English"
        }
    }

    /// The `AppleLanguages` override this maps to, or `nil` to defer to the system.
    var localeOverride: [String]? {
        switch self {
        case .system: nil
        case .russian: ["ru"]
        case .english: ["en"]
        }
    }
}

final class Preferences: ObservableObject {
    static let shared = Preferences()

    @Published var postCaptureAction: PostCaptureAction {
        didSet { defaults.set(postCaptureAction.rawValue, forKey: Keys.postCaptureAction) }
    }
    @Published var defaultColor: NSColor {
        didSet {
            guard let data = try? NSKeyedArchiver.archivedData(withRootObject: defaultColor, requiringSecureCoding: true) else { return }
            defaults.set(data, forKey: Keys.defaultColor)
        }
    }
    @Published var defaultLineWidth: Double {
        didSet { defaults.set(defaultLineWidth, forKey: Keys.defaultLineWidth) }
    }
    @Published var appLanguage: AppLanguage {
        didSet {
            defaults.set(appLanguage.rawValue, forKey: Keys.appLanguage)
            // `AppleLanguages` only affects which `.lproj` `Bundle.main` resolves to at
            // launch, so this has no visible effect until the app restarts.
            if let override = appLanguage.localeOverride {
                defaults.set(override, forKey: "AppleLanguages")
            } else {
                defaults.removeObject(forKey: "AppleLanguages")
            }
        }
    }
    // Stored as two plain Ints (not a single `HotkeyShortcut`) because that's what
    // `UserDefaults` round-trips without any custom (de)serialization.
    @Published var hotkeyKeyCode: Int {
        didSet { defaults.set(hotkeyKeyCode, forKey: Keys.hotkeyKeyCode) }
    }
    @Published var hotkeyModifiers: Int {
        didSet { defaults.set(hotkeyModifiers, forKey: Keys.hotkeyModifiers) }
    }

    var hotkeyShortcut: HotkeyShortcut {
        get { HotkeyShortcut(keyCode: UInt32(hotkeyKeyCode), modifiers: UInt32(hotkeyModifiers)) }
        set {
            hotkeyKeyCode = Int(newValue.keyCode)
            hotkeyModifiers = Int(newValue.modifiers)
        }
    }

    // Internal (not private) so tests can point a fresh instance at an isolated
    // UserDefaults suite instead of polluting the developer's real defaults domain.
    enum Keys {
        static let postCaptureAction = "postCaptureAction"
        static let defaultColor = "defaultColorData"
        static let defaultLineWidth = "defaultLineWidth"
        static let appLanguage = "appLanguage"
        static let hotkeyKeyCode = "hotkeyKeyCode"
        static let hotkeyModifiers = "hotkeyModifiers"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        postCaptureAction = PostCaptureAction(rawValue: defaults.string(forKey: Keys.postCaptureAction) ?? "") ?? .copyToClipboard
        defaultLineWidth = defaults.object(forKey: Keys.defaultLineWidth) as? Double ?? 4
        appLanguage = AppLanguage(rawValue: defaults.string(forKey: Keys.appLanguage) ?? "") ?? .system
        hotkeyKeyCode = defaults.object(forKey: Keys.hotkeyKeyCode) as? Int ?? Int(HotkeyShortcut.default.keyCode)
        hotkeyModifiers = defaults.object(forKey: Keys.hotkeyModifiers) as? Int ?? Int(HotkeyShortcut.default.modifiers)

        if let data = defaults.data(forKey: Keys.defaultColor),
           let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) {
            defaultColor = color
        } else {
            defaultColor = .systemRed
        }
    }
}
