import AppKit
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotkey: GlobalHotkey?
    private var session: OverlaySession?
    private var isCapturing = false
    private var hotkeyObservation: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerHotkey()
        hotkeyObservation = Preferences.shared.$hotkeyKeyCode
            .combineLatest(Preferences.shared.$hotkeyModifiers)
            .dropFirst() // the initial pair is already handled by the call above
            .sink { [weak self] _, _ in self?.registerHotkey() }
    }

    private func registerHotkey() {
        let shortcut = Preferences.shared.hotkeyShortcut
        guard let newHotkey = GlobalHotkey(keyCode: shortcut.keyCode, modifiers: shortcut.modifiers, onPress: { [weak self] in
            self?.startCapture()
        }) else {
            showHotkeyConflictAlert(for: shortcut)
            return
        }
        hotkey = newHotkey
    }

    private func showHotkeyConflictAlert(for shortcut: HotkeyShortcut) {
        let alert = NSAlert()
        alert.messageText = String(localized: "Не удалось назначить хоткей")
        alert.informativeText = String(format: String(localized: "Комбинация %@ уже используется и недоступна."), shortcut.displayString)
        alert.addButton(withTitle: String(localized: "ОК"))
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    func startCapture() {
        guard session == nil, !isCapturing else { return }

        guard ScreenPermissions.isGranted else {
            ScreenPermissions.request()
            ScreenPermissions.showPermissionAlert()
            return
        }

        isCapturing = true
        Task { @MainActor [self] in
            defer { self.isCapturing = false }
            do {
                let captures = try await ScreenCaptureService.captureAllDisplays()
                guard !captures.isEmpty else { return }
                let newSession = OverlaySession(captures: captures) { [weak self] in
                    self?.session = nil
                }
                session = newSession
                newSession.present()
            } catch {
                NSSound.beep()
            }
        }
    }
}
