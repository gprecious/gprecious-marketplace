import Foundation

/// A single scan snapshot. `timestamp` is caller-injected for test determinism.
/// `totalBytes` is derived: it always equals the sum of `perModule` values.
public struct ScanRecord: Sendable, Equatable, Identifiable {
    /// Caller-injected identity (UUID or "scan-<n>"); the persisted primary key.
    public let id: String
    public let timestamp: Date
    /// module id → reclaimable bytes for that module at scan time.
    public let perModule: [String: Int64]
    /// Always `== perModule.values.reduce(0, +)`.
    public let totalBytes: Int64

    public init(id: String, timestamp: Date, perModule: [String: Int64]) {
        self.id = id
        self.timestamp = timestamp
        self.perModule = perModule
        self.totalBytes = perModule.values.reduce(0, +)
    }
}
