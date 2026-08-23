import SwiftUI

@main
struct ScreenshotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.openWindow) private var openWindow
    @ObservedObject private var preferences = Preferences.shared

    var body: some Scene {
        MenuBarExtra("Screenshot", systemImage: "camera.viewfinder") {
            Button(String(format: String(localized: "Сделать скриншот (%@)"), preferences.hotkeyShortcut.displayString)) {
                appDelegate.startCapture()
            }
            Divider()
            SettingsLink { Text("Настройки…") }
            Button("О HogShot") { openWindow(id: "about") }
            Divider()
            Button("Выйти") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
        }

        Window("О HogShot", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)
    }
}
