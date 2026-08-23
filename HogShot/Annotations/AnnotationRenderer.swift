import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// Draws annotations into a `CGContext`. Used both by the live overlay preview and by
/// the final export, so on-screen and exported results can never drift apart.
///
/// Contract: the caller's context must already be top-left-origin / y-down before any
/// drawing happens — `OverlayView` gets this for free via `isFlipped == true`; offscreen
/// bitmap contexts must apply a manual flip transform right after creation. Path drawing
/// needs exactly that one ambient flip. `CGImage` draws (e.g. the pixelate case below)
/// need one MORE, local flip on top of it — verified empirically with a ground-truth
/// four-quadrant test image; dropping the local flip renders images upside down even
/// though the ambient flip alone is correct for paths. Use `drawImageRightSideUp`
/// instead of `ctx.draw(_:in:)` for every `CGImage` draw under this contract. Annotation
/// points are always in that same top-left/y-down pixel space, matching `source`'s own
/// pixel grid, so no per-call coordinate translation is needed.
enum AnnotationRenderer {
    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    static func draw(_ annotations: [Annotation], into ctx: CGContext, source: CGImage) {
        for annotation in annotations {
            draw(annotation, into: ctx, source: source)
        }
    }

    /// Draws `image` into `rect`, adding the local counter-flip that `CGImage` draws
    /// need on top of this file's ambient y-down convention — see the file-level
    /// doc comment. Always use this instead of `ctx.draw(_:in:)` under that contract.
    static func drawImageRightSideUp(_ image: CGImage, in rect: CGRect, ctx: CGContext) {
        ctx.saveGState()
        ctx.translateBy(x: 0, y: rect.minY + rect.maxY)
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(image, in: rect)
        ctx.restoreGState()
    }

    private static func draw(_ annotation: Annotation, into ctx: CGContext, source: CGImage) {
        guard !annotation.points.isEmpty else { return }
        ctx.saveGState()
        defer { ctx.restoreGState() }

        switch annotation.tool {
        case .arrow:
            guard annotation.points.count >= 2 else { break }
            drawArrow(from: annotation.points[0], to: annotation.points.last!, in: ctx, annotation: annotation)

        case .line:
            guard annotation.points.count >= 2 else { break }
            ctx.setStrokeColor(annotation.color.cgColor)
            ctx.setLineWidth(annotation.lineWidth)
            ctx.setLineCap(.round)
            ctx.move(to: annotation.points[0])
            ctx.addLine(to: annotation.points.last!)
            ctx.strokePath()

        case .rectangle:
            guard annotation.points.count >= 2 else { break }
            let rect = CGRect(p1: annotation.points[0], p2: annotation.points.last!)
            ctx.setStrokeColor(annotation.color.cgColor)
            ctx.setLineWidth(annotation.lineWidth)
            ctx.stroke(rect)

        case .ellipse:
            guard annotation.points.count >= 2 else { break }
            let rect = CGRect(p1: annotation.points[0], p2: annotation.points.last!)
            ctx.setStrokeColor(annotation.color.cgColor)
            ctx.setLineWidth(annotation.lineWidth)
            ctx.strokeEllipse(in: rect)

        case .pen:
            guard annotation.points.count >= 2 else { break }
            ctx.setStrokeColor(annotation.color.cgColor)
            ctx.setLineWidth(annotation.lineWidth)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            ctx.move(to: annotation.points[0])
            for point in annotation.points.dropFirst() {
                ctx.addLine(to: point)
            }
            ctx.strokePath()

        case .highlighter:
            guard annotation.points.count >= 2 else { break }
            ctx.setBlendMode(.multiply)
            ctx.setStrokeColor(annotation.color.withAlphaComponent(0.4).cgColor)
            ctx.setLineWidth(annotation.lineWidth * 4)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            ctx.move(to: annotation.points[0])
            for point in annotation.points.dropFirst() {
                ctx.addLine(to: point)
            }
            ctx.strokePath()

        case .text:
            drawText(annotation, in: ctx)

        case .pixelate:
            guard annotation.points.count >= 2 else { break }
            pixelate(annotation, in: ctx, source: source)
        }
    }

    private static func drawArrow(from start: CGPoint, to end: CGPoint, in ctx: CGContext, annotation: Annotation) {
        ctx.setStrokeColor(annotation.color.cgColor)
        ctx.setFillColor(annotation.color.cgColor)
        ctx.setLineWidth(annotation.lineWidth)
        ctx.setLineCap(.round)

        let angle = atan2(end.y - start.y, end.x - start.x)
        let headLength = max(12, annotation.lineWidth * 4)
        let headAngle = CGFloat.pi / 7

        let shaftEnd = CGPoint(
            x: end.x - cos(angle) * headLength * 0.6,
            y: end.y - sin(angle) * headLength * 0.6
        )
        ctx.move(to: start)
        ctx.addLine(to: shaftEnd)
        ctx.strokePath()

        let p1 = CGPoint(x: end.x - headLength * cos(angle - headAngle), y: end.y - headLength * sin(angle - headAngle))
        let p2 = CGPoint(x: end.x - headLength * cos(angle + headAngle), y: end.y - headLength * sin(angle + headAngle))
        ctx.move(to: end)
        ctx.addLine(to: p1)
        ctx.addLine(to: p2)
        ctx.closePath()
        ctx.fillPath()
    }

    private static func drawText(_ annotation: Annotation, in ctx: CGContext) {
        guard !annotation.text.isEmpty, let origin = annotation.points.first else { return }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: annotation.fontSize, weight: .semibold),
            .foregroundColor: annotation.color,
        ]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: annotation.text, attributes: attributes))

        // CoreText draws with a y-up baseline model; flip locally so it lands correctly
        // in our shared y-down convention without affecting sibling annotations.
        ctx.saveGState()
        ctx.translateBy(x: origin.x, y: origin.y + annotation.fontSize)
        ctx.scaleBy(x: 1, y: -1)
        ctx.textPosition = .zero
        CTLineDraw(line, ctx)
        ctx.restoreGState()
    }

    private static func pixelate(_ annotation: Annotation, in ctx: CGContext, source: CGImage) {
        let imageBounds = CGRect(x: 0, y: 0, width: source.width, height: source.height)
        let rect = CGRect(p1: annotation.points[0], p2: annotation.points.last!).intersection(imageBounds)
        guard !rect.isEmpty, let cropped = source.cropping(to: rect) else { return }

        let scale = max(6, annotation.lineWidth * 2)
        let filter = CIFilter.pixellate()
        filter.inputImage = CIImage(cgImage: cropped)
        filter.scale = Float(scale)
        filter.center = CGPoint(x: rect.width / 2, y: rect.height / 2)

        guard let output = filter.outputImage?.clamped(to: CGRect(x: 0, y: 0, width: rect.width, height: rect.height)),
              let rendered = ciContext.createCGImage(output, from: CGRect(x: 0, y: 0, width: rect.width, height: rect.height))
        else { return }

        drawImageRightSideUp(rendered, in: rect, ctx: ctx)
    }
}

private extension CGRect {
    init(p1: CGPoint, p2: CGPoint) {
        self.init(
            x: min(p1.x, p2.x),
            y: min(p1.y, p2.y),
            width: abs(p1.x - p2.x),
            height: abs(p1.y - p2.y)
        )
    }
}
