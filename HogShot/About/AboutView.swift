import SwiftUI
import AppKit

struct AboutView: View {
    @ObservedObject private var preferences = Preferences.shared

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
    private var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)

            Text("HogShot")
                .font(.title2)
                .bold()

            Text(String(format: String(localized: "Версия %@ (%@)"), version, build))
                .font(.callout)
                .foregroundStyle(.secondary)

            Text(String(format: String(localized: "Скриншоты с аннотациями по хоткею %@"), preferences.hotkeyShortcut.displayString))
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Text("Автор: Ivan Baranovskii")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(width: 280)
    }
}
