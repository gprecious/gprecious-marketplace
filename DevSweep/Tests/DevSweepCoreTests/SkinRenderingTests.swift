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

// MARK: - Shared skin fixtures

/// Representative reclaimable levels — one per band plus an empty case (mirrors --render-samples).
let representativeStates: [(label: String, state: ReclaimVisualState)] = {
    let low: Int64 = 5_000_000_000
    let high: Int64 = 20_000_000_000
    return [
        ("0", ReclaimVisualState(reclaimableBytes: 0, low: low, high: high)),
        ("2gb", ReclaimVisualState(reclaimableBytes: 2_000_000_000, low: low, high: high)),
        ("12gb", ReclaimVisualState(reclaimableBytes: 12_000_000_000, low: low, high: high)),
        ("30gb", ReclaimVisualState(reclaimableBytes: 30_000_000_000, low: low, high: high)),
    ]
}()

private let renderHeight: CGFloat = 18

// MARK: - Free skins (template, monochrome)

@Test func freeSkinCatalogContainsGaugeAndBattery() {
    let freeIds = SkinCatalog.free.map(\.id)
    #expect(freeIds.contains("gauge"))
    #expect(freeIds.contains("battery"))
    let allFree = SkinCatalog.free.allSatisfy { $0.isFree }
    #expect(allFree)
}

@Test func freeSkinsRenderExactHeightNonEmptyTemplateAtEveryBand() {
    for skin in SkinCatalog.free {
        for sample in representativeStates {
            let image = skin.image(for: sample.state, height: renderHeight)
            #expect(image.size.height == renderHeight, "\(skin.id)-\(sample.label) height")
            #expect(image.isTemplate == true, "\(skin.id)-\(sample.label) isTemplate")
            #expect(PixelInspection.isNonEmpty(image), "\(skin.id)-\(sample.label) non-empty")
        }
    }
}

@Test func freeSkinsAreDeterministic() {
    for skin in SkinCatalog.free {
        for sample in representativeStates {
            let a = skin.image(for: sample.state, height: renderHeight)
            let b = skin.image(for: sample.state, height: renderHeight)
            #expect(PixelInspection.rawPixels(a) == PixelInspection.rawPixels(b), "\(skin.id)-\(sample.label) determinism")
        }
    }
}

@Test func gaugeSkinFillGrowsWithReclaimableBytes() {
    // More reclaimable bytes ⇒ at least as many drawn (non-zero) pixels as a lower band.
    let gauge = GaugeSkin()
    func drawnBytes(_ state: ReclaimVisualState) -> Int {
        (PixelInspection.rawPixels(gauge.image(for: state, height: renderHeight)) ?? Data()).reduce(0) { $0 + ($1 != 0 ? 1 : 0) }
    }
    let low = drawnBytes(representativeStates[1].state)  // 2GB
    let high = drawnBytes(representativeStates[2].state) // 12GB
    #expect(high > low)
}
