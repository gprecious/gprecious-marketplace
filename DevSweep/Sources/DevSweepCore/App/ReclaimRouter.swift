import Foundation

/// Routes approved `CleanupItem`s to the module that owns each one and runs the reclaim.
/// Ownership is decided by the item id's module prefix (`itemId.split(":").first == module.id`).
/// Items with no owning module fail in place with `.failed("no owning module")`. Every result —
/// routed or failed — is written to the audit log via `StoreBuilders.auditRecords`. Outcomes are
/// returned in input order. `now` is injected so audit timestamps are deterministic in tests.
public struct ReclaimRouter: Sendable {
    private let modules: [any CleanupModule]
    private let store: any Store
    private let now: @Sendable () -> Date

    public init(
        modules: [any CleanupModule],
        store: any Store,
        now: @escaping @Sendable () -> Date
    ) {
        self.modules = modules
        self.store = store
        self.now = now
    }

    /// Partition `items` by owning module (decided by the item id's `<moduleId>:` prefix),
    /// reclaim each module's batch (honoring `dryRun`), record the combined outcomes to the
    /// audit log, and return them in input order. Use this when you only have item ids;
    /// prefer `reclaim(grouped:dryRun:)` when the owning module is already known (it routes
    /// modules whose ids are raw filesystem paths, e.g. node_modules, which carry no prefix).
    public func reclaim(_ items: [CleanupItem], dryRun: Bool) async -> [ReclaimOutcome] {
        // Group owned items per module (per-module input order preserved), preserving overall
        // input order so the unowned-item failures land in the right slots.
        var grouped: [(module: String, items: [CleanupItem])] = []
        var indexByModule: [String: Int] = [:]
        for item in items {
            let moduleId = owningModuleId(for: item.id)
            if let existing = indexByModule[moduleId] {
                grouped[existing].items.append(item)
            } else {
                indexByModule[moduleId] = grouped.count
                grouped.append((module: moduleId, items: [item]))
            }
        }
        return await route(grouped: grouped, allItems: items, dryRun: dryRun)
    }

    /// Reclaim items already grouped by their owning module id (as produced by
    /// `DetectorRegistry.scanGrouped`). Routes by the authoritative module id from the scan —
    /// NOT by parsing `item.id` — so modules whose item ids are raw filesystem paths with no
    /// `<moduleId>:` prefix (e.g. node_modules) reclaim correctly. Groups whose id matches no
    /// known module fail in place with `.failed("no owning module")`. Audit recording and
    /// input-order semantics match `reclaim(_:dryRun:)`.
    public func reclaim(
        grouped: [(module: String, items: [CleanupItem])],
        dryRun: Bool
    ) async -> [ReclaimOutcome] {
        let allItems = grouped.flatMap(\.items)
        return await route(grouped: grouped, allItems: allItems, dryRun: dryRun)
    }

    /// Shared core: reclaim each group through its named module, reassemble outcomes in the
    /// order of `allItems`, persist the audit log, and return them.
    private func route(
        grouped: [(module: String, items: [CleanupItem])],
        allItems: [CleanupItem],
        dryRun: Bool
    ) async -> [ReclaimOutcome] {
        var routed: [String: ReclaimOutcome] = [:]
        for group in grouped {
            guard !group.items.isEmpty,
                  let module = modules.first(where: { $0.id == group.module }) else { continue }
            for outcome in await module.reclaim(group.items, dryRun: dryRun) {
                routed[outcome.item.id] = outcome
            }
        }

        let outcomes = allItems.map { item in
            routed[item.id] ?? ReclaimOutcome(item: item, status: .failed(message: "no owning module"))
        }

        await store.recordAudit(StoreBuilders.auditRecords(timestamp: now(), from: outcomes))
        return outcomes
    }

    /// The token before the item id's first ":", used as the owning module id for prefix-based
    /// routing. A path-shaped id (no ":") yields the whole string, which matches no module.
    private func owningModuleId(for itemId: String) -> String {
        itemId.split(separator: ":").first.map(String.init) ?? itemId
    }
}
