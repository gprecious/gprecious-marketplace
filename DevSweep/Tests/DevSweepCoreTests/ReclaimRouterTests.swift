import Foundation
import Testing
@testable import DevSweepCore

// MARK: - Helpers

private func item(_ id: String, _ bytes: Int64) -> CleanupItem {
    CleanupItem(id: id, path: nil, sizeBytes: bytes, lastUsed: nil,
                safety: .autoSafe, reclaimMethod: .cliCommand(executable: "x", arguments: []))
}

/// Recording double: captures the items + dryRun flag each reclaim pass received, and echoes one
/// outcome per item (deleted when live, dryRun when planning) so tests can observe both routing
/// and status mapping. The existing `MockCleanupModule` echoes items but ignores `dryRun` and
/// records nothing, so misrouting would be invisible — this double makes routing observable.
private actor RecordingModule: CleanupModule {
    nonisolated let id: String
    nonisolated let displayName: String
    private(set) var receivedItems: [CleanupItem] = []
    private(set) var receivedDryRun: [Bool] = []

    init(id: String) {
        self.id = id
        self.displayName = id.uppercased()
    }

    func isAvailable() async -> Bool { true }
    func scan() async -> [CleanupItem] { [] }
    func reclaim(_ items: [CleanupItem], dryRun: Bool) async -> [ReclaimOutcome] {
        receivedItems.append(contentsOf: items)
        receivedDryRun.append(dryRun)
        return items.map { item in
            ReclaimOutcome(
                item: item,
                status: dryRun ? .dryRun(plannedBytes: item.sizeBytes) : .deleted(bytes: item.sizeBytes)
            )
        }
    }
}

private let fixedNow = Date(timeIntervalSince1970: 5000)

private func router(_ modules: [any CleanupModule], _ store: any Store) -> ReclaimRouter {
    ReclaimRouter(modules: modules, store: store, now: { fixedNow })
}

// MARK: - Routing

@Test func routesItemsToTheirOwningModule() async {
    let x = RecordingModule(id: "x")
    let y = RecordingModule(id: "y")
    let store = InMemoryStore()

    let outcomes = await router([x, y], store)
        .reclaim([item("x:a", 10), item("y:b", 20), item("x:c", 30)], dryRun: true)

    // Each module sees only its own items, in input order.
    #expect(await x.receivedItems.map(\.id) == ["x:a", "x:c"])
    #expect(await y.receivedItems.map(\.id) == ["y:b"])
    // Outcomes come back in input order, one per item.
    #expect(outcomes.map(\.item.id) == ["x:a", "y:b", "x:c"])
}

// MARK: - dryRun pass-through (no side effects)

@Test func dryRunIsForwardedToEveryModule() async {
    let x = RecordingModule(id: "x")
    let y = RecordingModule(id: "y")
    let store = InMemoryStore()

    let outcomes = await router([x, y], store)
        .reclaim([item("x:a", 10), item("y:b", 20)], dryRun: true)

    #expect(await x.receivedDryRun == [true])
    #expect(await y.receivedDryRun == [true])
    // Planning only — every outcome is a dryRun plan, nothing is deleted.
    #expect(outcomes.allSatisfy { $0.status == .dryRun(plannedBytes: $0.item.sizeBytes) })
}

@Test func liveReclaimForwardsDryRunFalseAndDeletes() async {
    let x = RecordingModule(id: "x")
    let store = InMemoryStore()

    let outcomes = await router([x], store).reclaim([item("x:a", 64)], dryRun: false)

    #expect(await x.receivedDryRun == [false])
    #expect(outcomes.map(\.status) == [.deleted(bytes: 64)])
}

// MARK: - Audit recording

@Test func recordsOneAuditEntryPerItem() async {
    // Reuse the shared MockCleanupModule double; it echoes the routed items.
    let x = MockCleanupModule(id: "x", displayName: "X", available: true, items: [])
    let y = MockCleanupModule(id: "y", displayName: "Y", available: true, items: [])
    let store = InMemoryStore()
    let items = [item("x:a", 10), item("y:b", 20), item("x:c", 30), item("z:d", 40)]

    _ = await router([x, y], store).reclaim(items, dryRun: true)

    let audit = await store.auditLog(limit: 100)
    // One entry per item, including the unowned "z:d".
    #expect(audit.count == items.count)
    #expect(audit.allSatisfy { $0.timestamp == fixedNow })
}

@Test func itemsWithNoOwningModuleFail() async {
    let x = MockCleanupModule(id: "x", displayName: "X", available: true, items: [])
    let store = InMemoryStore()

    let outcomes = await router([x], store).reclaim([item("z:orphan", 99)], dryRun: true)

    #expect(outcomes.count == 1)
    #expect(outcomes[0].status == .failed(message: "no owning module"))

    let audit = await store.auditLog(limit: 10)
    #expect(audit.count == 1)
    #expect(audit[0].status == "failed")
    #expect(audit[0].bytesReclaimed == 0)
    #expect(audit[0].moduleId == "z")
}

@Test func auditStatusReflectsEachOutcome() async {
    let x = RecordingModule(id: "x")   // returns .deleted when live
    let store = InMemoryStore()

    // x:a owned (live delete) + z:b unowned (fail) in one pass.
    _ = await router([x], store).reclaim([item("x:a", 10), item("z:b", 5)], dryRun: false)

    let audit = await store.auditLog(limit: 10)
    let byItem = Dictionary(uniqueKeysWithValues: audit.map { ($0.itemId, $0) })
    #expect(byItem["x:a"]?.status == "deleted")
    #expect(byItem["x:a"]?.bytesReclaimed == 10)
    #expect(byItem["z:b"]?.status == "failed")
    #expect(byItem["z:b"]?.bytesReclaimed == 0)
}

// MARK: - Grouped routing (authoritative module id; for modules whose item ids are raw paths)

/// node_modules emits raw filesystem-path ids with NO "<moduleId>:" prefix, so prefix parsing
/// would fail them. Grouped routing uses the scan's owning module id directly and reclaims them.
@Test func groupedRoutesByModuleIdNotItemIdPrefix() async {
    let node = RecordingModule(id: "node-modules")
    let store = InMemoryStore()
    let pathItem = item("/Users/dev/proj/node_modules", 512) // path-shaped id, no prefix

    let outcomes = await router([node], store).reclaim(
        grouped: [(module: "node-modules", items: [pathItem])],
        dryRun: true
    )

    #expect(await node.receivedItems.map(\.id) == ["/Users/dev/proj/node_modules"])
    #expect(outcomes.count == 1)
    #expect(outcomes[0].status == .dryRun(plannedBytes: 512))
}

@Test func groupedUnknownModuleGroupFailsInPlace() async {
    let x = RecordingModule(id: "x")
    let store = InMemoryStore()

    let outcomes = await router([x], store).reclaim(
        grouped: [(module: "ghost", items: [item("/some/path", 10)])],
        dryRun: true
    )

    #expect(outcomes.count == 1)
    #expect(outcomes[0].status == .failed(message: "no owning module"))
    #expect(await x.receivedItems.isEmpty)
}

@Test func groupedPreservesInputOrderAndRecordsAudit() async {
    let a = RecordingModule(id: "a")
    let b = RecordingModule(id: "b")
    let store = InMemoryStore()

    let outcomes = await router([a, b], store).reclaim(
        grouped: [
            (module: "a", items: [item("/p/a1", 1), item("/p/a2", 2)]),
            (module: "b", items: [item("b:keyed", 3)]) // prefixed id routes fine here too
        ],
        dryRun: false
    )

    #expect(outcomes.map(\.item.id) == ["/p/a1", "/p/a2", "b:keyed"])
    #expect(outcomes.allSatisfy { if case .deleted = $0.status { return true } else { return false } })

    let audit = await store.auditLog(limit: 100)
    #expect(audit.count == 3)
    #expect(audit.allSatisfy { $0.timestamp == fixedNow })
}
