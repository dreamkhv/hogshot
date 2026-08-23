import CoreGraphics

/// The eight drag handles around a selection rectangle, in the same top-left/y-down
/// pixel space as everything else (`top` uses `minY`, `bottom` uses `maxY`).
enum ResizeHandle: CaseIterable {
    case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left

    func point(in rect: CGRect) -> CGPoint {
        switch self {
        case .topLeft: CGPoint(x: rect.minX, y: rect.minY)
        case .top: CGPoint(x: rect.midX, y: rect.minY)
        case .topRight: CGPoint(x: rect.maxX, y: rect.minY)
        case .right: CGPoint(x: rect.maxX, y: rect.midY)
        case .bottomRight: CGPoint(x: rect.maxX, y: rect.maxY)
        case .bottom: CGPoint(x: rect.midX, y: rect.maxY)
        case .bottomLeft: CGPoint(x: rect.minX, y: rect.maxY)
        case .left: CGPoint(x: rect.minX, y: rect.midY)
        }
    }

    func applying(delta: CGPoint, to rect: CGRect) -> CGRect {
        var r = rect
        switch self {
        case .topLeft:
            r.origin.x += delta.x; r.origin.y += delta.y
            r.size.width -= delta.x; r.size.height -= delta.y
        case .top:
            r.origin.y += delta.y; r.size.height -= delta.y
        case .topRight:
            r.origin.y += delta.y
            r.size.width += delta.x; r.size.height -= delta.y
        case .right:
            r.size.width += delta.x
        case .bottomRight:
            r.size.width += delta.x; r.size.height += delta.y
        case .bottom:
            r.size.height += delta.y
        case .bottomLeft:
            r.origin.x += delta.x
            r.size.width -= delta.x; r.size.height += delta.y
        case .left:
            r.origin.x += delta.x; r.size.width -= delta.x
        }
        return r.standardized
    }
}
