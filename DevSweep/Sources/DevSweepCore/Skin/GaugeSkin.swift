import AppKit

/// Free skin: a charging-style vertical gauge. A rounded-rect body (faint track) fills from the
/// bottom proportional to `fillRatio`; the top band thickens the outline for emphasis. Drawn as a
/// **template** (alpha-as-mask, monochrome) so the menubar recolours it for light/dark and the
/// status item's tint escalates it to yellow/red.
public struct GaugeSkin: SkinModule {
    public let id = "gauge"
    public let displayName = "게이지"
    public let isFree = true

    public init() {}

    public func image(for state: ReclaimVisualState, height: CGFloat) -> NSImage {
        let width = (height * 0.62).rounded()
        return SkinCanvas.image(width: width, height: height, isTemplate: true) { _, size in
            let lineWidth: CGFloat = state.isCritical ? 2.0 : 1.25
            let inset = lineWidth / 2 + 1
            let body = CGRect(
                x: inset,
                y: inset,
                width: size.width - inset * 2,
                height: size.height - inset * 2
            )
            let radius = min(3, body.width / 3)

            // Track outline (faint).
            let track = NSBezierPath(roundedRect: body, xRadius: radius, yRadius: radius)
            track.lineWidth = lineWidth
            NSColor.black.withAlphaComponent(state.isCritical ? 0.9 : 0.5).setStroke()
            track.stroke()

            // Proportional fill from the bottom, clipped to the rounded body interior.
            guard state.fillRatio > 0 else { return }
            let interior = body.insetBy(dx: lineWidth, dy: lineWidth)
            let fillHeight = (interior.height * CGFloat(state.fillRatio)).rounded()
            guard fillHeight > 0 else { return }
            let fillRect = CGRect(x: interior.minX, y: interior.minY, width: interior.width, height: fillHeight)
            let innerRadius = max(0, radius - lineWidth)
            let clip = NSBezierPath(roundedRect: interior, xRadius: innerRadius, yRadius: innerRadius)
            NSGraphicsContext.saveGraphicsState()
            clip.addClip()
            NSColor.black.withAlphaComponent(0.95).setFill()
            NSBezierPath(rect: fillRect).fill()
            NSGraphicsContext.restoreGraphicsState()
        }
    }
}
