import Foundation
import Testing
@testable import DevSweepCore

private func cliItem(_ id: String, _ bytes: Int64) -> CleanupItem {
    CleanupItem(id: id, path: nil, sizeBytes: bytes, lastUsed: nil,
                safety: .autoSafe, reclaimMethod: .cliCommand(executable: "/usr/bin/env", arguments: []))
}

@Test func registrySkipsUnavailableModules() async {
    let a = MockCleanupModule(id: "a", displayName: "A", available: true, items: [cliItem("a:x", 10)])
    let b = MockCleanupModule(id: "b", displayName: "B", available: false, items: [cliItem("b:y", 20)])
    let reg = DetectorRegistry(modules: [a, b])
    let items = await reg.scanAll()
    #expect(items.map(\.id) == ["a:x"])
}

@Test func registryMergesAvailableModulesInIndexOrder() async {
    let a = MockCleanupModule(id: "a", displayName: "A", available: true, items: [cliItem("a:x", 10)])
    let b = MockCleanupModule(id: "b", displayName: "B", available: true, items: [cliItem("b:y", 20)])
    let reg = DetectorRegistry(modules: [a, b])
    let grouped = await reg.scanGrouped()
    #expect(grouped.map(\.module) == ["a", "b"])
    #expect(grouped.flatMap(\.items).map(\.id) == ["a:x", "b:y"])
}

@Test func registryEmptyWhenAllUnavailable() async {
    let a = MockCleanupModule(id: "a", displayName: "A", available: false, items: [cliItem("a:x", 10)])
    let reg = DetectorRegistry(modules: [a])
    #expect(await reg.scanAll().isEmpty)
    #expect(await reg.scanGrouped().isEmpty)
}
