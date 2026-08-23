import SwiftUI

struct SettingsView: View {
    @ObservedObject private var preferences = Preferences.shared
    @State private var showsRestartAlert = false

    var body: some View {
        Form {
            Picker("Язык", selection: $preferences.appLanguage) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.label).tag(language)
                }
            }
            .onChange(of: preferences.appLanguage) { _, _ in
                showsRestartAlert = true
            }

            HStack {
                Text("Хоткей")
                Spacer()
                HotkeyRecorderView(shortcut: $preferences.hotkeyShortcut)
            }

            Divider()

            Picker("После захвата", selection: $preferences.postCaptureAction) {
                ForEach(PostCaptureAction.allCases) { action in
                    Text(action.label).tag(action)
                }
            }

            ColorPicker(
                "Цвет по умолчанию",
                selection: Binding(
                    get: { Color(nsColor: preferences.defaultColor) },
                    set: { preferences.defaultColor = NSColor($0) }
                )
            )

            VStack(alignment: .leading) {
                Text(String(format: String(localized: "Толщина линии: %d"), Int(preferences.defaultLineWidth)))
                Slider(value: $preferences.defaultLineWidth, in: 1...12, step: 1)
            }
        }
        .padding(20)
        .frame(width: 360)
        .alert("Перезапустить HogShot?", isPresented: $showsRestartAlert) {
            Button("Перезапустить") { AppRelauncher.relaunch() }
            Button("Позже", role: .cancel) {}
        } message: {
            Text("Чтобы сменить язык интерфейса, приложение нужно перезапустить.")
        }
    }
}
