import AppKit
import CoreGraphics

enum ScreenPermissions {
    static var isGranted: Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// Triggers the system consent prompt on first use. Returns immediately; the
    /// actual grant only takes effect after the user responds, so callers should
    /// re-check `isGranted` rather than assuming success.
    static func request() {
        CGRequestScreenCaptureAccess()
    }

    static func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = String(localized: "Нужен доступ к записи экрана")
        alert.informativeText = String(localized: "Чтобы делать скриншоты, разрешите приложению доступ в Настройках системы → Конфиденциальность и безопасность → Запись экрана.")
        alert.addButton(withTitle: String(localized: "Открыть настройки"))
        alert.addButton(withTitle: String(localized: "Отмена"))
        NSApp.activate()
        if alert.runModal() == .alertFirstButtonReturn {
            openSystemSettings()
        }
    }

    private static func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else { return }
        NSWorkspace.shared.open(url)
    }
}
