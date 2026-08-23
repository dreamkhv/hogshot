import AppKit

enum AppRelauncher {
    /// Launches a fresh copy of this app and terminates the current one. Used after a
    /// setting (like the UI language) that only takes effect via `Bundle.main`'s
    /// resolution at launch, so it can't be applied to the already-running process.
    static func relaunch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, _ in }
        NSApp.terminate(nil)
    }
}
