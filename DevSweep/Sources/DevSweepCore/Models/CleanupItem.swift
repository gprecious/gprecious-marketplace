import Foundation

/// A single reclaim candidate produced by a detector module. `scan()` never deletes;
/// it only describes what *could* be reclaimed.
public struct CleanupItem: Sendable, Equatable, Identifiable {
    /// Stable identity (path for path-based items, or "module:key" for CLI-based ones).
    public let id: String
    /// Filesystem path. `nil` for CLI-based reclaim (e.g. docker build cache).
    public let path: String?
    public let sizeBytes: Int64
    /// Last-used timestamp if known (used by recency checks). `nil` if unknown.
    public let lastUsed: Date?
    /// Mutable so the Safety Layer can downgrade a candidate to `.protected`.
    public var safety: SafetyClass
    public let reclaimMethod: ReclaimMethod

    public init(
        id: String,
        path: String?,
        sizeBytes: Int64,
        lastUsed: Date?,
        safety: SafetyClass,
        reclaimMethod: ReclaimMethod
    ) {
        self.id = id
        self.path = path
        self.sizeBytes = sizeBytes
        self.lastUsed = lastUsed
        self.safety = safety
        self.reclaimMethod = reclaimMethod
    }
}
