import Foundation
import Testing
@testable import DevSweepCore

@Test func recentUseActiveWhenModifiedWithinThreshold() async {
    let temp = TempDir()
    defer { temp.cleanup() }
    let file = temp.writeFile("fresh.txt", "x")
    // mtime = now; fixed clock = now -> within 30 days.
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    try? FileManager.default.setAttributes([.modificationDate: now], ofItemAtPath: file)

    let signal = RecentUseSignal(thresholdDays: 30, now: { now })
    #expect(await signal.isActive(path: file) == true)
    #expect(signal.name == "recent-use")
}

@Test func recentUseInactiveWhenOlderThanThreshold() async {
    let temp = TempDir()
    defer { temp.cleanup() }
    let file = temp.writeFile("stale.txt", "x")
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let old = now.addingTimeInterval(-40 * 86_400)  // 40 days ago
    try? FileManager.default.setAttributes([.modificationDate: old], ofItemAtPath: file)

    let signal = RecentUseSignal(thresholdDays: 30, now: { now })
    #expect(await signal.isActive(path: file) == false)
}

@Test func recentUseInactiveForMissingPath() async {
    let signal = RecentUseSignal(thresholdDays: 30, now: { Date() })
    #expect(await signal.isActive(path: "/nonexistent/thing") == false)
}
