import Foundation
import Testing
@testable import DevSweepCore

@Test func appConfigDefaultsMatchSpec() {
    let c = AppConfig.default
    #expect(c.scanInterval == 6 * 3600)
    #expect(c.diskPressurePct == 0.15)
    #expect(c.notifyThresholdBytes == 20_000_000_000)
    #expect(c.gaugeLowBytes == 5_000_000_000)
    #expect(c.gaugeHighBytes == 20_000_000_000)
}

@Test func appConfigDefaultInitEqualsDefaultConstant() {
    #expect(AppConfig() == AppConfig.default)
}

@Test func appConfigEquatableDistinguishesMutatedField() {
    var c = AppConfig()
    c.scanInterval = 60
    #expect(c != AppConfig.default)
}

@Test func appConfigInitAcceptsCustomValues() {
    let c = AppConfig(
        scanInterval: 100,
        diskPressurePct: 0.2,
        notifyThresholdBytes: 1,
        gaugeLowBytes: 2,
        gaugeHighBytes: 3
    )
    #expect(c.scanInterval == 100)
    #expect(c.diskPressurePct == 0.2)
    #expect(c.notifyThresholdBytes == 1)
    #expect(c.gaugeLowBytes == 2)
    #expect(c.gaugeHighBytes == 3)
}
