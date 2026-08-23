import SwiftUI

/// Floating toolbar shown once a selection exists. Hosted inside `OverlayView` via
/// `NSHostingView` and repositioned manually next to the current selection.
struct OverlayToolbarView: View {
    @Binding var selectedTool: AnnotationTool?
    @Binding var color: Color
    let canUndo: Bool
    let canRedo: Bool
    let onUndo: () -> Void
    let onRedo: () -> Void
    let onCopy: () -> Void
    let onSave: () -> Void
    let onCancel: () -> Void

    private let palette: [Color] = [.red, .orange, .yellow, .green, .blue, .white]

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 2) {
                ForEach(AnnotationTool.allCases) { tool in
                    Button {
                        selectedTool = (selectedTool == tool) ? nil : tool
                    } label: {
                        Image(systemName: tool.symbolName)
                            .frame(width: 26, height: 26)
                            .background(selectedTool == tool ? Color.accentColor.opacity(0.35) : .clear)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider().frame(height: 20)

            HStack(spacing: 6) {
                ForEach(palette, id: \.self) { swatch in
                    Button { color = swatch } label: {
                        Circle()
                            .fill(swatch)
                            .frame(width: 16, height: 16)
                            .overlay(Circle().stroke(.white, lineWidth: color == swatch ? 2 : 0))
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider().frame(height: 20)

            Button(action: onUndo) { Image(systemName: "arrow.uturn.backward") }
                .buttonStyle(.plain).disabled(!canUndo)
            Button(action: onRedo) { Image(systemName: "arrow.uturn.forward") }
                .buttonStyle(.plain).disabled(!canRedo)

            Divider().frame(height: 20)

            Button(action: onCancel) { Image(systemName: "xmark") }.buttonStyle(.plain)
            Button(action: onSave) { Image(systemName: "square.and.arrow.down") }.buttonStyle(.plain)
            Button(action: onCopy) {
                Label("Копировать", systemImage: "doc.on.doc")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .fixedSize()
    }
}
