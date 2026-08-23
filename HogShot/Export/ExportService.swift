import AppKit
import UniformTypeIdentifiers

enum ExportError: Error {
    case cropFailed
    case encodingFailed
}

enum ExportService {
    /// Crops `source` to `cropRect` (in the same top-left/y-down pixel space as
    /// `annotations`) and bakes the annotations into the result.
    static func flattenedImage(source: CGImage, cropRect: CGRect, annotations: [Annotation]) throws -> CGImage {
        let sourceBounds = CGRect(x: 0, y: 0, width: source.width, height: source.height)
        let rect = cropRect.integral.intersection(sourceBounds)
        guard !rect.isEmpty, let cropped = source.cropping(to: rect) else {
            throw ExportError.cropFailed
        }

        let width = cropped.width
        let height = cropped.height
        let colorSpace = cropped.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw ExportError.cropFailed
        }

        // Flip to top-left/y-down so path-based annotation drawing matches
        // AnnotationRenderer's shared coordinate convention.
        ctx.translateBy(x: 0, y: CGFloat(height))
        ctx.scaleBy(x: 1, y: -1)
        AnnotationRenderer.drawImageRightSideUp(cropped, in: CGRect(x: 0, y: 0, width: width, height: height), ctx: ctx)

        // Annotation points are relative to the full source image; shift into
        // crop-relative space before drawing them on top.
        ctx.saveGState()
        ctx.translateBy(x: -rect.origin.x, y: -rect.origin.y)
        AnnotationRenderer.draw(annotations, into: ctx, source: source)
        ctx.restoreGState()

        guard let result = ctx.makeImage() else { throw ExportError.encodingFailed }
        return result
    }

    static func copyToPasteboard(_ image: CGImage) {
        let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([nsImage])
    }

    static func promptSave(_ image: CGImage) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = defaultFileName()
        panel.canCreateDirectories = true
        NSApp.activate()
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? save(image, to: url)
        }
    }

    static func save(_ image: CGImage, to url: URL) throws {
        guard let data = pngData(for: image) else { throw ExportError.encodingFailed }
        try data.write(to: url)
    }

    static func pngData(for image: CGImage) -> Data? {
        NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    }

    private static func defaultFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return "Screenshot \(formatter.string(from: Date())).png"
    }
}
