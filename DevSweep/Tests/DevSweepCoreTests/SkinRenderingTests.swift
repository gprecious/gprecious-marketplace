import AppKit
import Foundation
import Testing
@testable import DevSweepCore

// MARK: - Catalog

@Test func skinCatalogDefaultSkinIdIsGauge() {
    #expect(SkinCatalog.defaultSkinId == "gauge")
}

@Test func skinCatalogReturnsNilForUnknownId() {
    #expect(SkinCatalog.skin(id: "does-not-exist") == nil)
}

// MARK: - SkinCanvas (headless drawing helper)

@Test func skinCanvasReportsRequestedPointHeightAndDoubleScalePixels() {
    let image = SkinCanvas.image(width: 12, height: 18, isTemplate: false) { cg, size in
        cg.setFillColor(NSColor.black.cgColor)
        cg.fill(CGRect(origin: .zero, size: size))
    }
    #expect(image.size.height == 18)
    #expect(image.size.width == 12)
    let pixels = PixelInspection.pixelSize(image)
    #expect(pixels?.width == 24)  // @2x
    #expect(pixels?.height == 36) // @2x
}

@Test func skinCanvasProducesNonEmptyImageWhenDrawing() {
    let image = SkinCanvas.image(width: 10, height: 10, isTemplate: false) { cg, size in
        cg.setFillColor(NSColor.white.cgColor)
        cg.fill(CGRect(origin: .zero, size: size))
    }
    #expect(PixelInspection.isNonEmpty(image))
}

@Test func skinCanvasProducesEmptyImageWhenNotDrawing() {
    let image = SkinCanvas.image(width: 10, height: 10, isTemplate: false) { _, _ in }
    #expect(PixelInspection.isNonEmpty(image) == false)
}

@Test func skinCanvasIsDeterministicForIdenticalDrawing() {
    func render() -> NSImage {
        SkinCanvas.image(width: 14, height: 18, isTemplate: false) { cg, size in
            cg.setFillColor(NSColor(calibratedRed: 0.2, green: 0.6, blue: 0.9, alpha: 1).cgColor)
            cg.fillEllipse(in: CGRect(x: 1, y: 1, width: size.width - 2, height: size.height - 2))
        }
    }
    #expect(PixelInspection.rawPixels(render()) == PixelInspection.rawPixels(render()))
}

@Test func skinCanvasPropagatesTemplateFlag() {
    let template = SkinCanvas.image(width: 8, height: 8, isTemplate: true) { _, _ in }
    let colour = SkinCanvas.image(width: 8, height: 8, isTemplate: false) { _, _ in }
    #expect(template.isTemplate == true)
    #expect(colour.isTemplate == false)
}
