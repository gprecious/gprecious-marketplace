import Foundation

/// Runs a registry scan, snapshots it into a `ScanRecord` (per-module reclaimable sums),
/// persists it through the `Store`, and returns the record. `idProvider`/`now` are injected
/// so identity and timestamps are deterministic in tests.
public struct ScanCoordinator: Sendable {
    private let registry: DetectorRegistry
    private let store: any Store
    private let idProvider: @Sendable () -> String
    private let now: @Sendable () -> Date

    public init(
        registry: DetectorRegistry,
        store: any Store,
        idProvider: @escaping @Sendable () -> String,
        now: @escaping @Sendable () -> Date
    ) {
        self.registry = registry
        self.store = store
        self.idProvider = idProvider
        self.now = now
    }

    /// Scan all available modules → build the snapshot → persist → return it.
    @discardableResult
    public func runScan() async -> ScanRecord {
        let grouped = await registry.scanGrouped()
        let record = ScanRecord(id: idProvider(), timestamp: now(), from: grouped)
        await store.recordScan(record)
        return record
    }
}
