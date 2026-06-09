import Foundation
import Testing
@testable import DevSweepCore

private func item(_ id: String, _ bytes: Int64) -> CleanupItem {
    CleanupItem(id: id, path: nil, sizeBytes: bytes, lastUsed: nil,
                safety: .autoSafe, reclaimMethod: .cliCommand(executable: "x", arguments: []))
}

@Test func scanCoordinatorPersistsScanAndReturnsRecord() async {
    let modA = MockCleanupModule(id: "a", displayName: "A", available: true,
                                 items: [item("a:x", 100), item("a:y", 50)])
    let modB = MockCleanupModule(id: "b", displayName: "B", available: true,
                                 items: [item("b:z", 200)])
    let registry = DetectorRegistry(modules: [modA, modB])
    let store = InMemoryStore()
    let coord = ScanCoordinator(
        registry: registry,
        store: store,
        idProvider: { "scan-1" },
        now: { Date(timeIntervalSince1970: 1000) }
    )

    let record = await coord.runScan()

    #expect(record.id == "scan-1")
    #expect(record.timestamp == Date(timeIntervalSince1970: 1000))
    #expect(record.perModule["a"] == 150)
    #expect(record.perModule["b"] == 200)
    #expect(record.totalBytes == 350)

    // The returned record is exactly what was persisted as the latest scan.
    let latest = await store.latestScan()
    #expect(latest == record)
}

@Test func scanCoordinatorSkipsUnavailableModules() async {
    let on = MockCleanupModule(id: "on", displayName: "On", available: true, items: [item("on:x", 10)])
    let off = MockCleanupModule(id: "off", displayName: "Off", available: false, items: [item("off:y", 999)])
    let registry = DetectorRegistry(modules: [on, off])
    let store = InMemoryStore()
    let coord = ScanCoordinator(
        registry: registry,
        store: store,
        idProvider: { "scan-2" },
        now: { Date(timeIntervalSince1970: 2000) }
    )

    let record = await coord.runScan()

    #expect(record.perModule["on"] == 10)
    #expect(record.perModule["off"] == nil)
    #expect(record.totalBytes == 10)
}
