import AppKit
import CoreGraphics
@testable import HogShot

/// Builds a CGImage whose top half and bottom half are different solid colors, in the
/// sense a human looking at the resulting PNG would call "top"/"bottom". This is the
/// ground-truth fixture the orientation-regression tests are built around: if any
/// drawing path silently flips the image, the sampled top/bottom colors swap.
func makeTopBottomImage(width: Int, height: Int, top: NSColor, bottom: NSColor) -> CGImage {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    // Draw via a *non*-flipped NSGraphicsContext so "higher y" means "visual top",
    // exactly like how any ordinary (non-view) drawing establishes "up".
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
    top.setFill()
    NSRect(x: 0, y: height / 2, width: width, height: height - height / 2).fill()
    bottom.setFill()
    NSRect(x: 0, y: 0, width: width, height: height / 2).fill()
    NSGraphicsContext.restoreGraphicsState()
    return ctx.makeImage()!
}

func makeSolidImage(width: Int, height: Int, color: NSColor) -> CGImage {
    makeTopBottomImage(width: width, height: height, top: color, bottom: color)
}

struct RGBA {
    let r: UInt8, g: UInt8, b: UInt8, a: UInt8
}

/// Reads back the raw bytes at a pixel. `(x, y)` are in the image's own row-major pixel
/// buffer space: row 0 is the top row as the image would be encoded to a PNG file.
func pixel(of image: CGImage, x: Int, y: Int) -> RGBA {
    let data = image.dataProvider!.data! as Data
    let bytesPerRow = image.bytesPerRow
    let bytesPerPixel = image.bitsPerPixel / 8
    let offset = y * bytesPerRow + x * bytesPerPixel
    return RGBA(r: data[offset], g: data[offset + 1], b: data[offset + 2], a: data[offset + 3])
}

func approxEqual(_ a: UInt8, _ b: UInt8, tolerance: UInt8 = 24) -> Bool {
    abs(Int(a) - Int(b)) <= Int(tolerance)
}

/// Renders `annotations` over a blank white canvas under the same "one ambient
/// top-left/y-down flip" contract that `ExportService` sets up for real exports, so
/// annotation coordinates behave exactly as they do in the shipping app.
func renderAnnotations(_ annotations: [Annotation], width: Int, height: Int, source: CGImage) -> CGImage {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    ctx.translateBy(x: 0, y: CGFloat(height))
    ctx.scaleBy(x: 1, y: -1)
    ctx.setFillColor(NSColor.white.cgColor)
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
    AnnotationRenderer.draw(annotations, into: ctx, source: source)
    return ctx.makeImage()!
}
