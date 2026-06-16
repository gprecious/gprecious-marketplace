import AppKit
import Testing
@testable import DevSweepCore

@Test func statusItemPresentationKeepsReadableTitleSeparateFromImageTint() {
    let style = StatusItemPresentation.style(forBytes: 0, low: 5, high: 20)

    #expect(style.imageTint.isEqual(NSColor.secondaryLabelColor))
    #expect(style.titleColor.isEqual(NSColor.labelColor))

    let title = StatusItemPresentation.attributedTitle("0 bytes", style: style)
    #expect(title.string == "0 bytes")
    #expect((title.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor)?.isEqual(NSColor.labelColor) == true)
}

@Test func statusItemPresentationUsesBoldTitleOnlyForHighPressure() {
    let regular = StatusItemPresentation.style(forBytes: 19, low: 5, high: 20)
    let critical = StatusItemPresentation.style(forBytes: 20, low: 5, high: 20)
    let manager = NSFontManager.shared

    #expect(manager.traits(of: regular.titleFont).contains(.boldFontMask) == false)
    #expect(manager.traits(of: critical.titleFont).contains(.boldFontMask) == true)
    #expect(critical.imageTint.isEqual(NSColor.systemRed))
}

@Test func statusItemPresentationAnchorsPopoverBelowButtonCenter() {
    let anchor = StatusItemPresentation.popoverAnchorRect(in: CGRect(x: 0, y: 0, width: 80, height: 22))

    #expect(abs(anchor.midX - 40) < 0.001)
    #expect(anchor.width == 1)
    #expect(anchor.height == 1)
    #expect(anchor.minY == -StatusItemPresentation.popoverVerticalOffset)
}

@Test func statusItemPresentationKeepsPopoverAnchorFiniteForTinyBounds() {
    let anchor = StatusItemPresentation.popoverAnchorRect(in: .zero)

    #expect(anchor.width == 1)
    #expect(anchor.height == 1)
    #expect(anchor.origin.x.isFinite)
    #expect(anchor.origin.y.isFinite)
}
