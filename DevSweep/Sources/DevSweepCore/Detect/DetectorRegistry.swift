/// Runs every available module's scan concurrently and merges the results. Modules whose
/// `isAvailable()` is false are skipped entirely. Output order is deterministic (module
/// declaration order), independent of which scan finishes first.
public struct DetectorRegistry: Sendable {
    private let modules: [any CleanupModule]

    public init(modules: [any CleanupModule]) {
        self.modules = modules
    }

    /// Flat list of all candidates from available modules, in module declaration order.
    public func scanAll() async -> [CleanupItem] {
        await scanGrouped().flatMap(\.items)
    }

    /// Candidates grouped by owning module id, in module declaration order. Modules that
    /// produce no items but are available are omitted from the grouping.
    public func scanGrouped() async -> [(module: String, items: [CleanupItem])] {
        let collected: [(Int, String, [CleanupItem])] =
        await withTaskGroup(of: (Int, String, [CleanupItem])?.self) { group in
            for (index, module) in modules.enumerated() {
                group.addTask {
                    guard await module.isAvailable() else { return nil }
                    let items = await module.scan()
                    return items.isEmpty ? nil : (index, module.id, items)
                }
            }
            var results: [(Int, String, [CleanupItem])] = []
            for await result in group {
                if let result { results.append(result) }
            }
            return results
        }
        let sorted = collected
            .sorted { $0.0 < $1.0 }
            .map { (module: $0.1, items: $0.2) }
        let survivors = Set(NestedItemSuppressor.suppressNested(sorted.flatMap(\.items)).map(\.id))
        return sorted
            .map { (module: $0.module, items: $0.items.filter { survivors.contains($0.id) }) }
            .filter { !$0.items.isEmpty }
    }
}
