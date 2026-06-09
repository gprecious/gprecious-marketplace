import Foundation
import Testing
@testable import DevSweepCore

/// Test double for `DiskSpaceProbe`. Returns a fixed, caller-configured snapshot so
/// trigger/notification policies can be exercised against deterministic disk state.
struct MockDiskSpaceProbe: DiskSpaceProbe {
    let freeBytes: Int64
    let totalBytes: Int64

    func snapshot() -> (freeBytes: Int64, totalBytes: Int64) {
        (freeBytes: freeBytes, totalBytes: totalBytes)
    }
}

@Test func mockDiskSpaceProbeReturnsConfiguredSnapshot() {
    let probe = MockDiskSpaceProbe(freeBytes: 10, totalBytes: 100)
    let snap = probe.snapshot()
    #expect(snap.freeBytes == 10)
    #expect(snap.totalBytes == 100)
}
