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

    /// Partition `items` by owning module, reclaim each module's batch (honoring `dryRun`),
    /// record the combined outcomes to the audit log, and return them in input order.
    public func reclaim(_ items: [CleanupItem], dryRun: Bool) async -> [ReclaimOutcome] {
        // Group owned items per module (per-module input order preserved).
        var ownedByModule: [String: [CleanupItem]] = [:]
        for item in items {
            guard let owner = owningModule(for: item.id) else { continue }
            ownedByModule[owner.id, default: []].append(item)
        }

        // Reclaim each owning module's batch, indexing every result by item id.
        var routed: [String: ReclaimOutcome] = [:]
        for module in modules {
            guard let owned = ownedByModule[module.id], !owned.isEmpty else { continue }
            for outcome in await module.reclaim(owned, dryRun: dryRun) {
                routed[outcome.item.id] = outcome
            }
        }

        // Reassemble in input order; anything without a routed result had no owning module.
        let outcomes = items.map { item in
            routed[item.id] ?? ReclaimOutcome(item: item, status: .failed(message: "no owning module"))
        }

        await store.recordAudit(StoreBuilders.auditRecords(timestamp: now(), from: outcomes))
        return outcomes
    }

    /// The module whose id matches the token before the item id's first ":", or `nil`.
    private func owningModule(for itemId: String) -> (any CleanupModule)? {
        guard let prefix = itemId.split(separator: ":").first.map(String.init) else { return nil }
        return modules.first { $0.id == prefix }
    }
}
