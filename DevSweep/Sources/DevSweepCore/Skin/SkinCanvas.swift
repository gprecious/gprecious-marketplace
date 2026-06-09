import AppKit

/// Headless @2x bitmap drawing helper shared by every skin.
///
/// Skins must render identically under `swift test` (no window server) and in the GUI, so we draw
/// into an offscreen `NSBitmapImageRep`-backed `NSGraphicsContext` rather than `NSImage.lockFocus`
/// (which can require a window-server connection). The returned `NSImage` is sized in **points** and
/// backed by a `@2x` pixel rep, so it stays crisp on Retina and reports the requested height to the
/// status item. Drawing is deterministic: identical inputs produce byte-identical pixels.
enum SkinCanvas {
    /// Render an image of `width × height` points at `scale`× pixel density.
    ///
    /// - Parameters:
    ///   - width/height: logical point size; `image.size` equals this.
    ///   - scale: pixel density (2 = Retina @2x).
    ///   - isTemplate: sets `NSImage.isTemplate` (free skins → `true` for system recolouring).
    ///   - draw: drawing closure in point coordinates (origin bottom-left). The current
    ///     `NSGraphicsContext` is set, so `NSBezierPath`/`NSColor`/`NSGradient` work; the matching
    ///     `CGContext` is passed for Core Graphics drawing.
    static func image(
        width: CGFloat,
        height: CGFloat,
        scale: CGFloat = 2,
        isTemplate: Bool,
        draw: (CGContext, CGSize) -> Void
    ) -> NSImage {
        let pointSize = CGSize(width: max(1, width), height: max(1, height))
        let pixelsWide = max(1, Int((pointSize.width * scale).rounded()))
        let pixelsHigh = max(1, Int((pointSize.height * scale).rounded()))

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelsWide,
            pixelsHigh: pixelsHigh,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return NSImage(size: pointSize)
        }
        // Report the point size so PNG export / status item treat the pixels as @2x.
        rep.size = NSSize(width: pointSize.width, height: pointSize.height)

        if let ctx = NSGraphicsContext(bitmapImageRep: rep) {
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = ctx
            let cg = ctx.cgContext
            cg.scaleBy(x: scale, y: scale) // draw in point coordinates
            draw(cg, pointSize)
            NSGraphicsContext.current?.flushGraphics()
            NSGraphicsContext.restoreGraphicsState()
        }

        let image = NSImage(size: pointSize)
        image.addRepresentation(rep)
        image.isTemplate = isTemplate
        return image
    }
}
