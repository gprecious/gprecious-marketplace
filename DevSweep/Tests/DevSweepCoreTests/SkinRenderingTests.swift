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

@Test func skinCanvasFillRectCoversEntirePixelBuffer() {
    // A full-bounds fill must map to every pixel — guards against half/double-scale CTM bugs that
    // leave part of the canvas unpainted (the M5 double-scale regression).
    let image = SkinCanvas.image(width: 12, height: 18, isTemplate: false) { cg, size in
        cg.setFillColor(NSColor.white.cgColor)
        cg.fill(CGRect(origin: .zero, size: size))
    }
    guard let rep = PixelInspection.bitmapRep(image), let ptr = rep.bitmapData else {
        #expect(Bool(false), "missing bitmap rep"); return
    }
    var opaquePixels = 0
    let total = rep.pixelsWide * rep.pixelsHigh
    for y in 0..<rep.pixelsHigh {
        for x in 0..<rep.pixelsWide where ptr[y * rep.bytesPerRow + x * rep.samplesPerPixel + 3] > 0 {
            opaquePixels += 1
        }
    }
    #expect(opaquePixels == total, "expected full coverage, got \(opaquePixels)/\(total)")
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

@Test func freeSkinOutlinesSpanAllFourEdges() {
    // Regression: every free skin's outline must reach all four edges, not clip to a corner
    // (the M5 AppKit double-scale bug rendered only the bottom-left quarter). Both gauge AND battery
    // use the same NSBezierPath outline path, so both are guarded here.
    for skin in SkinCatalog.free {
        let image = skin.image(for: representativeStates[0].state, height: 36) // band 0 = outline only
        guard let rep = PixelInspection.bitmapRep(image), let ptr = rep.bitmapData else {
            #expect(Bool(false), "\(skin.id): missing bitmap rep"); continue
        }
        let w = rep.pixelsWide, h = rep.pixelsHigh
        func hasInk(xRange: Range<Int>, yRange: Range<Int>) -> Bool {
            for y in yRange {
                for x in xRange where ptr[y * rep.bytesPerRow + x * rep.samplesPerPixel + 3] > 0 {
                    return true
                }
            }
            return false
        }
        let topBand = 0..<max(1, h * 18 / 100)
        let bottomBand = (h - max(1, h * 18 / 100))..<h
        let leftBand = 0..<max(1, w * 22 / 100)
        let rightBand = (w - max(1, w * 22 / 100))..<w
        #expect(hasInk(xRange: 0..<w, yRange: topBand), "\(skin.id): top edge missing")
        #expect(hasInk(xRange: 0..<w, yRange: bottomBand), "\(skin.id): bottom edge missing")
        #expect(hasInk(xRange: leftBand, yRange: 0..<h), "\(skin.id): left edge missing")
        #expect(hasInk(xRange: rightBand, yRange: 0..<h), "\(skin.id): right edge missing")
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

@Test func batterySkinFillGrowsWithReclaimableBytes() {
    let battery = BatterySkin()
    func drawnBytes(_ state: ReclaimVisualState) -> Int {
        (PixelInspection.rawPixels(battery.image(for: state, height: renderHeight)) ?? Data()).reduce(0) { $0 + ($1 != 0 ? 1 : 0) }
    }
    #expect(drawnBytes(representativeStates[2].state) > drawnBytes(representativeStates[1].state))
}

@Test func gaugeFillReachesInteriorTopWhenFullButNotWhenEmpty() {
    // Guards the fill geometry at fillRatio 1.0: the centre of the gauge near the top must be painted
    // when full, and transparent when empty (catches a fill rect that fails to reach the interior top).
    let low: Int64 = 5_000_000_000, high: Int64 = 20_000_000_000
    let skin = GaugeSkin()
    func centerInkNearTop(_ bytes: Int64) -> Bool {
        let image = skin.image(for: ReclaimVisualState(reclaimableBytes: bytes, low: low, high: high), height: 36)
        guard let rep = PixelInspection.bitmapRep(image), let ptr = rep.bitmapData else { return false }
        let cx = rep.pixelsWide / 2
        let y = rep.pixelsHigh / 4 // ~25% down from the top (bitmap row 0 = top)
        return ptr[y * rep.bytesPerRow + cx * rep.samplesPerPixel + 3] > 0
    }
    #expect(centerInkNearTop(30_000_000_000) == true)  // full → fill reaches the interior top
    #expect(centerInkNearTop(0) == false)              // empty → interior centre is unpainted
}

// MARK: - Paid skins (colour, non-template)

@Test func paidSkinCatalogContainsDotMatrixAndSynthwave() {
    let paidIds = SkinCatalog.paid.map(\.id)
    #expect(paidIds.contains("dot-matrix"))
    #expect(paidIds.contains("synthwave"))
    let nonePaidFree = SkinCatalog.paid.allSatisfy { !$0.isFree }
    #expect(nonePaidFree)
}

@Test func paidSkinsRenderExactHeightNonEmptyNonTemplateAtEveryBand() {
    for skin in SkinCatalog.paid {
        for sample in representativeStates {
            let image = skin.image(for: sample.state, height: renderHeight)
            #expect(image.size.height == renderHeight, "\(skin.id)-\(sample.label) height")
            #expect(image.isTemplate == false, "\(skin.id)-\(sample.label) isTemplate=false")
            #expect(PixelInspection.isNonEmpty(image), "\(skin.id)-\(sample.label) non-empty")
        }
    }
}

@Test func paidSkinsHaveChromaticPixelsInTopBand() {
    let critical = ReclaimVisualState(reclaimableBytes: 30_000_000_000, low: 5_000_000_000, high: 20_000_000_000)
    for skin in SkinCatalog.paid {
        let image = skin.image(for: critical, height: renderHeight)
        #expect(PixelInspection.hasChromaticPixel(image), "\(skin.id) should render colour")
    }
}

@Test func dotMatrixSkinMapsBandsToDistinctColors() {
    // The skin's purpose is band-coded colour: band 1 = amber (green-rich), band 2 = red (green-poor).
    // A bug that always picked one band colour would pass the "has-chromatic-pixel" test; this catches it.
    let low: Int64 = 5_000_000_000, high: Int64 = 20_000_000_000
    let skin = DotMatrixSkin()
    func mostSaturatedLitPixel(_ bytes: Int64) -> (r: Int, g: Int, b: Int)? {
        let image = skin.image(for: ReclaimVisualState(reclaimableBytes: bytes, low: low, high: high), height: 18)
        guard let rep = PixelInspection.bitmapRep(image), let ptr = rep.bitmapData else { return nil }
        var best: (r: Int, g: Int, b: Int)?
        var bestSaturation = -1
        for y in 0..<rep.pixelsHigh {
            for x in 0..<rep.pixelsWide {
                let p = y * rep.bytesPerRow + x * rep.samplesPerPixel
                let r = Int(ptr[p]), g = Int(ptr[p + 1]), b = Int(ptr[p + 2]), a = Int(ptr[p + 3])
                if a < 200 { continue } // lit cells are opaque
                let saturation = max(r, g, b) - min(r, g, b)
                if saturation > bestSaturation { bestSaturation = saturation; best = (r, g, b) }
            }
        }
        return best
    }
    let amber = mostSaturatedLitPixel(12_000_000_000) // band 1
    let red = mostSaturatedLitPixel(30_000_000_000)   // band 2
    #expect(amber != nil)
    #expect(red != nil)
    if let amber, let red {
        #expect(amber.g > red.g + 40, "amber green (\(amber.g)) should clearly exceed red green (\(red.g))")
        #expect(red.r > red.g, "the critical (band 2) lit colour should be red-dominant")
    }
}

@Test func synthwaveIsChromaticEvenWhenEmpty() {
    // Its neon track is always drawn, so it reads as colour at band 0 too.
    let empty = representativeStates[0].state
    let image = SynthwaveGaugeSkin().image(for: empty, height: renderHeight)
    #expect(PixelInspection.hasChromaticPixel(image))
}

@Test func paidSkinsAreDeterministic() {
    for skin in SkinCatalog.paid {
        for sample in representativeStates {
            let a = skin.image(for: sample.state, height: renderHeight)
            let b = skin.image(for: sample.state, height: renderHeight)
            #expect(PixelInspection.rawPixels(a) == PixelInspection.rawPixels(b), "\(skin.id)-\(sample.label) determinism")
        }
    }
}

@Test func catalogPartitionsAllSkinsIntoFreeAndPaid() {
    #expect(SkinCatalog.all.count == SkinCatalog.free.count + SkinCatalog.paid.count)
    #expect(SkinCatalog.free.count == 2)
    #expect(SkinCatalog.paid.count == 2)
    // Every skin id is unique.
    let ids = SkinCatalog.all.map(\.id)
    #expect(Set(ids).count == ids.count)
}

// MARK: - SkinRenderer

@Test func skinRendererDefaultsToGauge() {
    let renderer = SkinRenderer(config: .default)
    #expect(renderer.currentSkinId == "gauge")
    #expect(renderer.currentSkin.id == "gauge")
}

@Test func skinRendererFallsBackToDefaultForUnknownInitialId() {
    let renderer = SkinRenderer(config: .default, skinId: "bogus")
    #expect(renderer.currentSkinId == SkinCatalog.defaultSkinId)
}

@Test func skinRendererHonoursValidInitialId() {
    let renderer = SkinRenderer(config: .default, skinId: "battery")
    #expect(renderer.currentSkinId == "battery")
}

@Test func skinRendererSelectsValidSkinAndRejectsUnknown() {
    let renderer = SkinRenderer(config: .default)
    #expect(renderer.select(id: "battery") == true)
    #expect(renderer.currentSkinId == "battery")
    #expect(renderer.select(id: "nope") == false)
    #expect(renderer.currentSkinId == "battery") // unchanged
}

@Test func skinRendererRendersCurrentSkinAtRequestedHeight() {
    let renderer = SkinRenderer(config: .default, skinId: "synthwave")
    let image = renderer.image(forBytes: 30_000_000_000, height: 18)
    #expect(image.size.height == 18)
    #expect(PixelInspection.isNonEmpty(image))
}

@Test func skinRendererUsesConfigThresholdsForBandMapping() {
    // With a tiny high threshold, even a small byte total renders the critical state.
    let config = AppConfig(gaugeLowBytes: 1, gaugeHighBytes: 2)
    let renderer = SkinRenderer(config: config, skinId: "gauge")
    let image = renderer.image(forBytes: 100, height: 18)
    #expect(PixelInspection.isNonEmpty(image)) // full gauge, drawn
}
