import Foundation
import Testing
@testable import DevSweepCore

/// Test double for CleanupModule. Returns configured availability + items; reclaim
/// reports each item as a dry-run plan (no side effects).
struct MockCleanupModule: CleanupModule {
    let id: String
    let displayName: String
    let available: Bool
    let items: [CleanupItem]

    func isAvailable() async -> Bool { available }
    func scan() async -> [CleanupItem] { items }
    func reclaim(_ items: [CleanupItem], dryRun: Bool) async -> [ReclaimOutcome] {
        items.map { ReclaimOutcome(item: $0, status: .dryRun(plannedBytes: $0.sizeBytes)) }
    }
}

private func cliItem(_ id: String, _ bytes: Int64) -> CleanupItem {
    CleanupItem(id: id, path: nil, sizeBytes: bytes, lastUsed: nil,
                safety: .autoSafe, reclaimMethod: .cliCommand(executable: "/usr/bin/env", arguments: []))
}

@Test func mockCleanupModuleReportsConfiguredState() async {
    let m = MockCleanupModule(id: "m", displayName: "M", available: true, items: [cliItem("m:x", 42)])
    #expect(await m.isAvailable() == true)
    #expect(await m.scan().map(\.id) == ["m:x"])
    let outcomes = await m.reclaim(await m.scan(), dryRun: true)
    #expect(outcomes.first?.status == .dryRun(plannedBytes: 42))
}
