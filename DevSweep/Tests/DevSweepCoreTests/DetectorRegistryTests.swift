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

private struct StubModule: CleanupModule {
    let id: String; let displayName: String; let items: [CleanupItem]
    func isAvailable() async -> Bool { true }
    func scan() async -> [CleanupItem] { items }
    func reclaim(_ items: [CleanupItem], dryRun: Bool) async -> [ReclaimOutcome] { [] }
}

@Test func scanGroupedSuppressesNestedAcrossModules() async {
    let wt = CleanupItem(id: "/r/.worktrees/f", path: "/r/.worktrees/f", sizeBytes: 1, lastUsed: nil,
                         safety: .reviewNeeded, reclaimMethod: .cliCommand(executable: "/usr/bin/env",
                         arguments: ["git", "worktree", "remove", "/r/.worktrees/f"]))
    let nm = CleanupItem(id: "/r/.worktrees/f/node_modules", path: "/r/.worktrees/f/node_modules", sizeBytes: 1,
                         lastUsed: nil, safety: .reviewNeeded, reclaimMethod: .deletePath(toTrash: false))
    let registry = DetectorRegistry(modules: [
        StubModule(id: "git-worktrees", displayName: "Git Worktrees", items: [wt]),
        StubModule(id: "node-modules", displayName: "node_modules", items: [nm])
    ])
    let grouped = await registry.scanGrouped()
    let nodeGroup = grouped.first { $0.module == "node-modules" }
    #expect(nodeGroup == nil)   // its only item was nested under the worktree => suppressed => group omitted
}
