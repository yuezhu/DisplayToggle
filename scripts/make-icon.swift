// Renders Display Toggle's app icon into an .iconset folder (all macOS sizes).
// Original artwork drawn from plain shapes: two overlapping screens echoing the menu-bar
// symbol. SF Symbols themselves may not be used in app icons, so none are used here.
//
// Usage: swift scripts/make-icon.swift <output.iconset>   (scripts/make-icon.sh wraps this)
import AppKit

let canvas: CGFloat = 1024

func drawIcon(in ctx: CGContext) {
    // Work in top-left coordinates on a 1024 canvas.
    ctx.translateBy(x: 0, y: canvas)
    ctx.scaleBy(x: 1, y: -1)

    let colors = [CGColor(srgbRed: 0.33, green: 0.66, blue: 1.00, alpha: 1),
                  CGColor(srgbRed: 0.10, green: 0.36, blue: 0.86, alpha: 1)] as CFArray
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors, locations: [0, 1])!
    func fillGradient(_ path: CGPath) {
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 100), end: CGPoint(x: 0, y: 924), options: [])
        ctx.restoreGState()
    }
    func rounded(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> CGPath {
        CGPath(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerWidth: r, cornerHeight: r, transform: nil)
    }

    // macOS icon tile: 824pt rounded square on the 1024 canvas, with a soft drop shadow.
    let tile = rounded(100, 100, 824, 824, 185)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: CGColor(gray: 0, alpha: 0.35))  // shadow offsets ignore the flip: negative = down
    ctx.addPath(tile)
    ctx.setFillColor(CGColor(srgbRed: 0.10, green: 0.36, blue: 0.86, alpha: 1))
    ctx.fillPath()
    ctx.restoreGState()
    fillGradient(tile)

    let white = CGColor(gray: 1, alpha: 1)
    let line: CGFloat = 36

    // Back screen, upper right.
    ctx.addPath(rounded(440, 270, 380, 260, 36))
    ctx.setStrokeColor(white)
    ctx.setLineWidth(line)
    ctx.strokePath()

    // Front screen, lower left: filled with the tile gradient so it hides the back screen.
    let front = rounded(204, 390, 450, 304, 40)
    fillGradient(front)
    ctx.addPath(front)
    ctx.setStrokeColor(white)
    ctx.setLineWidth(line)
    ctx.strokePath()

    // Stand: neck and base under the front screen.
    ctx.setFillColor(white)
    ctx.addPath(rounded(409, 712, 40, 54, 6))
    ctx.fillPath()
    ctx.addPath(rounded(319, 758, 220, 34, 17))
    ctx.fillPath()
}

func png(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!.cgContext
    ctx.scaleBy(x: CGFloat(pixels) / canvas, y: CGFloat(pixels) / canvas)
    drawIcon(in: ctx)
    return rep.representation(using: .png, properties: [:])!
}

let out = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    try png(pixels: size).write(to: out.appendingPathComponent("icon_\(size)x\(size).png"))
    try png(pixels: size * 2).write(to: out.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
