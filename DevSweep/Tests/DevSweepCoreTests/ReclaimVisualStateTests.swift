import Foundation
import Testing
@testable import DevSweepCore

// Default gauge thresholds (decimal GB) mirror AppConfig.default.
private let low: Int64 = 5_000_000_000
private let high: Int64 = 20_000_000_000

@Test func reclaimVisualStateBandsAtRepresentativeLevels() {
    #expect(ReclaimVisualState(reclaimableBytes: 0, low: low, high: high).band == 0)
    #expect(ReclaimVisualState(reclaimableBytes: 2_000_000_000, low: low, high: high).band == 0)
    #expect(ReclaimVisualState(reclaimableBytes: 12_000_000_000, low: low, high: high).band == 1)
    #expect(ReclaimVisualState(reclaimableBytes: 30_000_000_000, low: low, high: high).band == 2)
}

@Test func reclaimVisualStateBandBoundariesAreInclusiveAtLowAndHigh() {
    #expect(ReclaimVisualState(reclaimableBytes: low - 1, low: low, high: high).band == 0)
    #expect(ReclaimVisualState(reclaimableBytes: low, low: low, high: high).band == 1)
    #expect(ReclaimVisualState(reclaimableBytes: high - 1, low: low, high: high).band == 1)
    #expect(ReclaimVisualState(reclaimableBytes: high, low: low, high: high).band == 2)
}

@Test func reclaimVisualStateFillRatioIsBytesOverHighClampedToUnitInterval() {
    #expect(ReclaimVisualState(reclaimableBytes: 0, low: low, high: high).fillRatio == 0)
    #expect(abs(ReclaimVisualState(reclaimableBytes: 2_000_000_000, low: low, high: high).fillRatio - 0.1) < 1e-9)
    #expect(abs(ReclaimVisualState(reclaimableBytes: 10_000_000_000, low: low, high: high).fillRatio - 0.5) < 1e-9)
    #expect(ReclaimVisualState(reclaimableBytes: high, low: low, high: high).fillRatio == 1.0)
    #expect(ReclaimVisualState(reclaimableBytes: 30_000_000_000, low: low, high: high).fillRatio == 1.0)
}

@Test func reclaimVisualStateClampsNegativeBytesToZero() {
    let state = ReclaimVisualState(reclaimableBytes: -100, low: low, high: high)
    #expect(state.band == 0)
    #expect(state.fillRatio == 0)
    #expect(state.isCritical == false)
}

@Test func reclaimVisualStateIsCriticalOnlyInTopBand() {
    #expect(ReclaimVisualState(reclaimableBytes: high - 1, low: low, high: high).isCritical == false)
    #expect(ReclaimVisualState(reclaimableBytes: high, low: low, high: high).isCritical == true)
    #expect(ReclaimVisualState(reclaimableBytes: 30_000_000_000, low: low, high: high).isCritical == true)
}

@Test func reclaimVisualStateGuardsAgainstNonPositiveHigh() {
    // Misconfigured thresholds must not divide by zero or crash; ratio stays finite in [0, 1].
    let state = ReclaimVisualState(reclaimableBytes: 10, low: 0, high: 0)
    #expect(state.fillRatio >= 0 && state.fillRatio <= 1)
    #expect(state.band == 2) // bytes (10) >= high (0)
    #expect(state.isCritical == true)
}

@Test func reclaimVisualStateIsEquatableByComponents() {
    let a = ReclaimVisualState(reclaimableBytes: 12_000_000_000, low: low, high: high)
    let b = ReclaimVisualState(reclaimableBytes: 13_000_000_000, low: low, high: high)
    #expect(a == ReclaimVisualState(reclaimableBytes: 12_000_000_000, low: low, high: high))
    #expect(a != b)
}

@Test func reclaimVisualStateConvenienceInitUsesConfigGaugeThresholds() {
    let config = AppConfig.default
    let fromConfig = ReclaimVisualState(reclaimableBytes: 12_000_000_000, config: config)
    let fromBounds = ReclaimVisualState(
        reclaimableBytes: 12_000_000_000,
        low: config.gaugeLowBytes,
        high: config.gaugeHighBytes
    )
    #expect(fromConfig == fromBounds)
}
