// Generates a 1024×1024 PNG placeholder app icon for DevSweep (broom on a teal squircle).
// Headless CoreGraphics drawing — no window server needed (same approach as SkinSampleRenderer).
// Usage: swift packaging/IconGen.swift <output.png>
// This is a PLACEHOLDER. Replace with a real designed icon before release.
import AppKit

guard CommandLine.arguments.count >= 2 else {
    FileHandle.standardError.write(Data("usage: IconGen.swift <output.png>\n".utf8))
    exit(2)
}
let outPath = CommandLine.arguments[1]
let S = 1024

guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: S, pixelsHigh: S,
                                 bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                 isPlanar: false, colorSpaceName: .deviceRGB,
                                 bytesPerRow: 0, bitsPerPixel: 0),
      let nsctx = NSGraphicsContext(bitmapImageRep: rep) else {
    FileHandle.standardError.write(Data("failed to create bitmap context\n".utf8))
    exit(1)
}
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = nsctx
let cg = nsctx.cgContext

func rgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor {
    CGColor(srgbRed: r, green: g, blue: b, alpha: a)
}

// --- background squircle with vertical gradient ---
let inset: CGFloat = 100
let bgRect = CGRect(x: inset, y: inset, width: CGFloat(S) - 2 * inset, height: CGFloat(S) - 2 * inset)
let bgPath = CGPath(roundedRect: bgRect, cornerWidth: 185, cornerHeight: 185, transform: nil)
cg.saveGState()
cg.addPath(bgPath)
cg.clip()
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let grad = CGGradient(colorsSpace: space,
                      colors: [rgb(0.10, 0.68, 0.56), rgb(0.04, 0.39, 0.52)] as CFArray,
                      locations: [0, 1])!
cg.drawLinearGradient(grad,
                      start: CGPoint(x: 0, y: bgRect.maxY),
                      end: CGPoint(x: 0, y: bgRect.minY),
                      options: [])
cg.restoreGState()

// --- broom (drawn in a rotated local frame) ---
let handleColor = rgb(0.93, 0.94, 0.96)
let ferruleColor = rgb(0.76, 0.80, 0.85)
let brushColor = rgb(0.97, 0.98, 0.99)
let bristleColor = rgb(0.58, 0.63, 0.70)

cg.saveGState()
cg.translateBy(x: 540, y: 500)
cg.rotate(by: -35 * .pi / 180)

// handle (rounded capsule)
cg.setLineCap(.round)
cg.setLineWidth(46)
cg.setStrokeColor(handleColor)
cg.move(to: CGPoint(x: 0, y: 70))
cg.addLine(to: CGPoint(x: 0, y: 370))
cg.strokePath()

// ferrule (band joining handle to brush)
cg.addPath(CGPath(roundedRect: CGRect(x: -80, y: 14, width: 160, height: 74),
                  cornerWidth: 20, cornerHeight: 20, transform: nil))
cg.setFillColor(ferruleColor)
cg.fillPath()

// brush head (fanning trapezoid)
cg.beginPath()
cg.move(to: CGPoint(x: -72, y: 32))
cg.addLine(to: CGPoint(x: 72, y: 32))
cg.addLine(to: CGPoint(x: 170, y: -242))
cg.addLine(to: CGPoint(x: -170, y: -242))
cg.closePath()
cg.setFillColor(brushColor)
cg.fillPath()

// bristle lines
cg.setLineWidth(9)
cg.setStrokeColor(bristleColor)
cg.setLineCap(.round)
for xTop in stride(from: -55.0, through: 55.0, by: 27.5) {
    cg.move(to: CGPoint(x: xTop, y: 24))
    cg.addLine(to: CGPoint(x: xTop * 2.7, y: -232))
    cg.strokePath()
}
cg.restoreGState()

// --- sparkles (4-point stars) implying "clean" ---
func star(_ cx: CGFloat, _ cy: CGFloat, _ R: CGFloat, alpha: CGFloat) {
    let r = R * 0.34
    let pts: [CGPoint] = [
        CGPoint(x: cx, y: cy + R), CGPoint(x: cx + r, y: cy + r),
        CGPoint(x: cx + R, y: cy), CGPoint(x: cx + r, y: cy - r),
        CGPoint(x: cx, y: cy - R), CGPoint(x: cx - r, y: cy - r),
        CGPoint(x: cx - R, y: cy), CGPoint(x: cx - r, y: cy + r)
    ]
    cg.beginPath()
    cg.move(to: pts[0])
    for p in pts.dropFirst() { cg.addLine(to: p) }
    cg.closePath()
    cg.setFillColor(rgb(1, 1, 1, Double(alpha)))
    cg.fillPath()
}
star(382, 648, 58, alpha: 0.95)
star(300, 566, 34, alpha: 0.80)
star(452, 706, 26, alpha: 0.70)

NSGraphicsContext.restoreGraphicsState()

guard let data = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("failed to encode PNG\n".utf8))
    exit(1)
}
do {
    try data.write(to: URL(fileURLWithPath: outPath))
    print("wrote \(outPath) (\(data.count) bytes)")
} catch {
    FileHandle.standardError.write(Data("write failed: \(error)\n".utf8))
    exit(1)
}
