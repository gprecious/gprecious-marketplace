import AppKit

/// Free skin: a horizontal battery whose charge level is `fillRatio`. A rounded body with a small
/// right-side terminal nub; the fill grows left→right. Drawn as a **template** (alpha-as-mask,
/// monochrome) so the menubar recolours it and the status item tint escalates with pressure.
public struct BatterySkin: SkinModule {
    public let id = "battery"
    public let displayName = "배터리"
    public let isFree = true

    public init() {}

    public func image(for state: ReclaimVisualState, height: CGFloat) -> NSImage {
        let width = (height * 1.7).rounded()
        return SkinCanvas.image(width: width, height: height, isTemplate: true) { _, size in
            let lineWidth: CGFloat = state.isCritical ? 1.75 : 1.25
            let nubWidth = (size.width * 0.08).rounded() + 1
            let nubHeight = (size.height * 0.4).rounded()
            let vInset = (lineWidth / 2 + 1).rounded()

            let body = CGRect(
                x: lineWidth / 2 + 1,
                y: vInset,
                width: size.width - nubWidth - lineWidth - 2,
                height: size.height - vInset * 2
            )
            let radius = min(2.5, body.height / 4)

            // Body outline.
            let outline = NSBezierPath(roundedRect: body, xRadius: radius, yRadius: radius)
            outline.lineWidth = lineWidth
            NSColor.black.withAlphaComponent(state.isCritical ? 0.9 : 0.55).setStroke()
            outline.stroke()

            // Terminal nub (right side).
            let nub = CGRect(
                x: body.maxX + 1,
                y: body.midY - nubHeight / 2,
                width: nubWidth,
                height: nubHeight
            )
            NSColor.black.withAlphaComponent(0.6).setFill()
            NSBezierPath(roundedRect: nub, xRadius: 1, yRadius: 1).fill()

            // Proportional charge fill (left→right), clipped inside the body.
            guard state.fillRatio > 0 else { return }
            let interior = body.insetBy(dx: lineWidth, dy: lineWidth)
            let fillWidth = (interior.width * CGFloat(state.fillRatio)).rounded()
            guard fillWidth > 0 else { return }
            let fillRect = CGRect(x: interior.minX, y: interior.minY, width: fillWidth, height: interior.height)
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
