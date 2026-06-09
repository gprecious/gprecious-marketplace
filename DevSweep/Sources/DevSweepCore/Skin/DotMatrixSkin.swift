import AppKit

/// Paid skin: a retro LED dot-matrix meter. Five pixel-style cells light left→right with
/// `fillRatio`; lit colour escalates by band (calm grey → amber → red). Rendered in **colour**
/// (`isTemplate = false`). Fixed sRGB colours keep the render deterministic regardless of the
/// system appearance / accessibility contrast settings.
public struct DotMatrixSkin: SkinModule {
    public let id = "dot-matrix"
    public let displayName = "도트 매트릭스"
    public let isFree = false

    public init() {}

    private static let unlit = NSColor(srgbRed: 0.5, green: 0.5, blue: 0.5, alpha: 0.22)
    private static let bandColors: [NSColor] = [
        NSColor(srgbRed: 0.62, green: 0.62, blue: 0.62, alpha: 1.0), // band 0 — calm grey
        NSColor(srgbRed: 1.0, green: 0.78, blue: 0.12, alpha: 1.0),  // band 1 — amber
        NSColor(srgbRed: 1.0, green: 0.27, blue: 0.21, alpha: 1.0),  // band 2 — red
    ]

    public func image(for state: ReclaimVisualState, height: CGFloat) -> NSImage {
        let width = (height * 2.4).rounded()
        return SkinCanvas.image(width: width, height: height, isTemplate: false) { _, size in
            let count = 5
            let gap = max(1, (size.width * 0.045).rounded())
            let side = min((size.width - gap * CGFloat(count + 1)) / CGFloat(count), size.height * 0.7)
            let y = ((size.height - side) / 2).rounded()
            let litCount = min(count, max(0, Int((Double(count) * state.fillRatio).rounded())))
            let lit = Self.bandColors[min(state.band, Self.bandColors.count - 1)]

            for i in 0..<count {
                let x = (gap + CGFloat(i) * (side + gap)).rounded()
                let cell = NSBezierPath(roundedRect: CGRect(x: x, y: y, width: side, height: side), xRadius: 1, yRadius: 1)
                (i < litCount ? lit : Self.unlit).setFill()
                cell.fill()
            }
        }
    }
}
