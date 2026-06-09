import Testing
@testable import DevSweepCore

@Test func packageVersionIsExposed() {
    #expect(DevSweepCore.version == "0.0.1")
}
