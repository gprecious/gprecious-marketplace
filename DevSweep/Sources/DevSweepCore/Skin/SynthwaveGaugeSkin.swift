import AppKit

/// Paid skin: a neon "synthwave" vertical gauge. A purple neon track is always drawn (so the skin
/// reads as colour even when empty); the fill is a cyan→magenta gradient that escalates to
/// magenta→red when critical. Rendered in **colour** (`isTemplate = false`) with fixed sRGB stops
/// for deterministic output.
public struct SynthwaveGaugeSkin: SkinModule {
    public let id = "synthwave"
    public let displayName = "신스웨이브"
    public let isFree = false

    public init() {}

    private static let track = NSColor(srgbRed: 0.55, green: 0.30, blue: 1.0, alpha: 0.9)
    private static let cyan = NSColor(srgbRed: 0.0, green: 0.90, blue: 1.0, alpha: 1.0)
    private static let magenta = NSColor(srgbRed: 1.0, green: 0.20, blue: 0.85, alpha: 1.0)
    private static let hotRed = NSColor(srgbRed: 1.0, green: 0.25, blue: 0.20, alpha: 1.0)

    public func image(for state: ReclaimVisualState, height: CGFloat) -> NSImage {
        let width = (height * 0.72).rounded()
        return SkinCanvas.image(width: width, height: height, isTemplate: false) { _, size in
            let lineWidth: CGFloat = state.isCritical ? 1.75 : 1.25
            let inset = lineWidth / 2 + 1
            let body = CGRect(x: inset, y: inset, width: size.width - inset * 2, height: size.height - inset * 2)
            let radius = min(3, body.width / 3)

            // Neon track outline (always present → always chromatic).
            let track = NSBezierPath(roundedRect: body, xRadius: radius, yRadius: radius)
            track.lineWidth = lineWidth
            Self.track.setStroke()
            track.stroke()

            // Gradient fill from the bottom.
            guard state.fillRatio > 0 else { return }
            let interior = body.insetBy(dx: lineWidth, dy: lineWidth)
            let fillHeight = (interior.height * CGFloat(state.fillRatio)).rounded()
            guard fillHeight > 0 else { return }
            let fillRect = CGRect(x: interior.minX, y: interior.minY, width: interior.width, height: fillHeight)
            let innerRadius = max(0, radius - lineWidth)

            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(roundedRect: interior, xRadius: innerRadius, yRadius: innerRadius).addClip()
            let bottom = state.isCritical ? Self.magenta : Self.cyan
            let top = state.isCritical ? Self.hotRed : Self.magenta
            if let gradient = NSGradient(starting: bottom, ending: top) {
                gradient.draw(in: NSBezierPath(rect: fillRect), angle: 90)
            }
            NSGraphicsContext.restoreGraphicsState()
        }
    }
}
