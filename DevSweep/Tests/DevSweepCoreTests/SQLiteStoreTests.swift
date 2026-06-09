import Foundation
import Testing
@testable import DevSweepCore

private func scan(_ id: String, _ epoch: TimeInterval, _ per: [String: Int64]) -> ScanRecord {
    ScanRecord(id: id, timestamp: Date(timeIntervalSince1970: epoch), perModule: per)
}

private func audit(_ epoch: TimeInterval, _ itemId: String, _ moduleId: String?,
                   _ bytes: Int64, _ status: String) -> AuditRecord {
    AuditRecord(timestamp: Date(timeIntervalSince1970: epoch), itemId: itemId, moduleId: moduleId,
                method: "deletePath(trash:false)", bytesReclaimed: bytes, status: status)
}

@Test func sqliteStoreRoundTripsScansAndAudits() async throws {
    let temp = TempDir()
    defer { temp.cleanup() }
    let dbPath = temp.url.appendingPathComponent("history.sqlite").path

    let store = try SQLiteStore(path: dbPath)
    await store.recordScan(scan("s1", 100, ["docker": 10, "npm": 20]))
    await store.recordScan(scan("s2", 200, ["docker": 30]))
    await store.recordAudit([
        audit(100, "docker:build-cache", "docker", 2_048, "deleted"),
        audit(200, "/Users/x/.npm", nil, 0, "dryRun"),
    ])

    let recent = await store.recentScans(limit: 10)
    #expect(recent.map(\.id) == ["s2", "s1"])                       // newest first
    let s1 = recent.first { $0.id == "s1" }
    #expect(s1?.perModule == ["docker": 10, "npm": 20])            // per_module JSON round-trip
    #expect(s1?.totalBytes == 30)
    #expect(await store.latestScan()?.id == "s2")

    let log = await store.auditLog(limit: 10)
    #expect(log.map(\.itemId) == ["/Users/x/.npm", "docker:build-cache"])  // newest first
    let deleted = log.first { $0.itemId == "docker:build-cache" }
    #expect(deleted?.moduleId == "docker")
    #expect(deleted?.bytesReclaimed == 2_048)
    #expect(deleted?.status == "deleted")
    #expect(deleted?.method == "deletePath(trash:false)")
    let dry = log.first { $0.itemId == "/Users/x/.npm" }
    #expect(dry?.moduleId == nil)                                   // NULL round-trips to nil
}

@Test func sqliteStorePersistsAcrossInstances() async throws {
    let temp = TempDir()
    defer { temp.cleanup() }
    let dbPath = temp.url.appendingPathComponent("persist.sqlite").path

    do {
        let first = try SQLiteStore(path: dbPath)
        await first.recordScan(scan("p1", 100, ["docker": 11]))
        await first.recordAudit([audit(100, "docker:x", "docker", 5, "deleted")])
    }
    // New instance over the SAME path — previously committed data must still be there.
    let second = try SQLiteStore(path: dbPath)
    #expect(await second.recentScans(limit: 10).map(\.id) == ["p1"])
    #expect(await second.latestScan()?.perModule == ["docker": 11])
    #expect(await second.auditLog(limit: 10).map(\.itemId) == ["docker:x"])
}

@Test func sqliteStoreRespectsLimitAndOrdering() async throws {
    let temp = TempDir()
    defer { temp.cleanup() }
    let dbPath = temp.url.appendingPathComponent("limit.sqlite").path

    let store = try SQLiteStore(path: dbPath)
    for (id, ts) in [("a", 100.0), ("c", 300.0), ("b", 200.0)] {
        await store.recordScan(scan(id, ts, ["docker": Int64(ts)]))
    }
    #expect(await store.recentScans(limit: 2).map(\.id) == ["c", "b"])

    for (itemId, ts) in [("x", 100.0), ("z", 300.0), ("y", 200.0)] {
        await store.recordAudit([audit(ts, itemId, nil, 0, "dryRun")])
    }
    #expect(await store.auditLog(limit: 2).map(\.itemId) == ["z", "y"])
}
