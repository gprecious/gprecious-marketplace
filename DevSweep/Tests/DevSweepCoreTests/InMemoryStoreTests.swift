import Foundation
import Testing
@testable import DevSweepCore

private func scan(_ id: String, _ epoch: TimeInterval, _ total: Int64) -> ScanRecord {
    ScanRecord(id: id, timestamp: Date(timeIntervalSince1970: epoch), perModule: ["docker": total])
}

private func audit(_ epoch: TimeInterval, _ itemId: String, _ status: String) -> AuditRecord {
    AuditRecord(timestamp: Date(timeIntervalSince1970: epoch), itemId: itemId, moduleId: nil,
                method: "deletePath(trash:false)", bytesReclaimed: 0, status: status)
}

@Test func recentScansReturnsLatestFirstWithLimit() async {
    let store = InMemoryStore()
    await store.recordScan(scan("a", 100, 10))
    await store.recordScan(scan("c", 300, 30))   // insert out of timestamp order on purpose
    await store.recordScan(scan("b", 200, 20))

    let recent = await store.recentScans(limit: 2)
    #expect(recent.map(\.id) == ["c", "b"])          // timestamp desc
    #expect(recent.count == 2)
}

@Test func latestScanIsMostRecentByTimestamp() async {
    let store = InMemoryStore()
    #expect(await store.latestScan() == nil)         // empty store
    await store.recordScan(scan("a", 100, 10))
    await store.recordScan(scan("c", 300, 30))
    await store.recordScan(scan("b", 200, 20))
    #expect(await store.latestScan()?.id == "c")
}

@Test func recentScansLimitLargerThanCountReturnsAll() async {
    let store = InMemoryStore()
    await store.recordScan(scan("a", 100, 10))
    await store.recordScan(scan("b", 200, 20))
    let recent = await store.recentScans(limit: 10)
    #expect(recent.map(\.id) == ["b", "a"])
}

@Test func auditLogIsLatestFirstWithLimit() async {
    let store = InMemoryStore()
    await store.recordAudit([audit(100, "x", "deleted"), audit(300, "z", "failed")])
    await store.recordAudit([audit(200, "y", "dryRun")])

    let log = await store.auditLog(limit: 2)
    #expect(log.map(\.itemId) == ["z", "y"])          // timestamp desc, limited
    #expect(await store.auditLog(limit: 10).map(\.itemId) == ["z", "y", "x"])
}
