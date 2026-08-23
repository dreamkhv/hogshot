import AppKit

enum AnnotationTool: String, CaseIterable, Identifiable {
    case arrow
    case rectangle
    case ellipse
    case line
    case pen
    case text
    case highlighter
    case pixelate

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .arrow: "arrow.up.right"
        case .rectangle: "rectangle"
        case .ellipse: "circle"
        case .line: "line.diagonal"
        case .pen: "pencil.tip"
        case .text: "textformat"
        case .highlighter: "highlighter"
        case .pixelate: "squareshape.split.3x3"
        }
    }
}

/// Coordinates are stored in source-image pixel space, not view points,
/// so the exported PNG and the on-screen preview never diverge on Retina displays.
struct Annotation: Identifiable {
    let id = UUID()
    var tool: AnnotationTool
    var points: [CGPoint] = []
    var color: NSColor = .systemRed
    var lineWidth: CGFloat = 4
    var text: String = ""
    var fontSize: CGFloat = 28

    var boundingBox: CGRect {
        guard !points.isEmpty else { return .zero }
        let xs = points.map(\.x)
        let ys = points.map(\.y)
        let minX = xs.min()!, maxX = xs.max()!
        let minY = ys.min()!, maxY = ys.max()!
        let pad = tool == .pen ? lineWidth : lineWidth * 2
        return CGRect(x: minX - pad, y: minY - pad, width: maxX - minX + pad * 2, height: maxY - minY + pad * 2)
    }
}
