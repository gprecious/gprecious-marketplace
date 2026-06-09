import Foundation
import Testing
@testable import DevSweepCore

/// Leaf A coverage: `ScanTriggerPolicy` priority/boundaries plus a `StatfsDiskSpaceProbe`
/// sanity check. Grouped under one suite so `swift test --filter ScanTrigger` runs both.
@Suite("ScanTriggerPolicy")
struct ScanTriggerPolicyTests {
    private let policy = ScanTriggerPolicy(config: .default)
    private let now = Date(timeIntervalSince1970: 1_000_000)
    private let healthy = (freeBytes: Int64(500), totalBytes: Int64(1000)) // 50% free
    private let pressured = (freeBytes: Int64(14), totalBytes: Int64(100)) // 14% free < 15%

    // MARK: priority — manual outranks everything

    @Test func manualRequestedReturnsManual() {
        let t = policy.evaluate(lastScan: now, now: now, disk: healthy, manualRequested: true)
        #expect(t == .manual)
    }

    @Test func manualBeatsDiskPressureAndInterval() {
        // Both disk pressure and an elapsed interval would fire — manual still wins.
        let old = now.addingTimeInterval(-AppConfig.default.scanInterval - 1)
        let t = policy.evaluate(lastScan: old, now: now, disk: pressured, manualRequested: true)
        #expect(t == .manual)
    }

    // MARK: disk pressure

    @Test func diskPressureWhenFreeRatioBelowThreshold() {
        // Recent scan keeps interval quiet; pressure should still trigger.
        let t = policy.evaluate(lastScan: now, now: now, disk: pressured, manualRequested: false)
        #expect(t == .diskPressure)
    }

    @Test func diskPressureBeatsInterval() {
        let old = now.addingTimeInterval(-AppConfig.default.scanInterval - 1)
        let t = policy.evaluate(lastScan: old, now: now, disk: pressured, manualRequested: false)
        #expect(t == .diskPressure)
    }

    @Test func noPressureAtExactThreshold() {
        // 15/100 == 0.15 is NOT strictly below diskPressurePct → no pressure.
        let edge = (freeBytes: Int64(15), totalBytes: Int64(100))
        let t = policy.evaluate(lastScan: now, now: now, disk: edge, manualRequested: false)
        #expect(t == .none)
    }

    // MARK: interval

    @Test func intervalWhenNoPriorScan() {
        let t = policy.evaluate(lastScan: nil, now: now, disk: healthy, manualRequested: false)
        #expect(t == .interval)
    }

    @Test func intervalWhenElapsedExactlyInterval() {
        let old = now.addingTimeInterval(-AppConfig.default.scanInterval) // delta == interval
        let t = policy.evaluate(lastScan: old, now: now, disk: healthy, manualRequested: false)
        #expect(t == .interval)
    }

    @Test func noneWhenJustUnderInterval() {
        let old = now.addingTimeInterval(-AppConfig.default.scanInterval + 1) // delta == interval - 1
        let t = policy.evaluate(lastScan: old, now: now, disk: healthy, manualRequested: false)
        #expect(t == .none)
    }

    // MARK: none

    @Test func noneWhenRecentAndHealthyAndNoManual() {
        let t = policy.evaluate(lastScan: now, now: now, disk: healthy, manualRequested: false)
        #expect(t == .none)
    }

    // MARK: defensive — zero total must not divide-by-zero or falsely report pressure

    @Test func noPressureWhenTotalBytesZero() {
        let t = policy.evaluate(
            lastScan: now, now: now,
            disk: (freeBytes: 0, totalBytes: 0), manualRequested: false
        )
        #expect(t == .none)
    }

    // MARK: StatfsDiskSpaceProbe sanity (Leaf A second deliverable)

    @Test func statfsProbeSnapshotOfRootIsSane() {
        let probe = StatfsDiskSpaceProbe(path: "/")
        let snap = probe.snapshot()
        #expect(snap.totalBytes > 0)
        #expect(snap.freeBytes > 0)
        #expect(snap.freeBytes <= snap.totalBytes)
    }
}
