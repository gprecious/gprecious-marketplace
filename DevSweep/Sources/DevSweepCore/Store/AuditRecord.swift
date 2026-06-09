import Foundation

/// One audit entry for a single reclaim result. Append-only; never mutated after write.
public struct AuditRecord: Sendable, Equatable {
    public let timestamp: Date
    public let itemId: String
    /// Owning module id, or `nil` for path-based items with no module prefix.
    public let moduleId: String?
    /// Human-readable reclaim method, e.g. "deletePath(trash:false)" /
    /// "cliCommand(docker builder prune -f)".
    public let method: String
    /// Actual bytes when `deleted`, planned bytes when `dryRun`, otherwise 0.
    public let bytesReclaimed: Int64
    /// "deleted" / "dryRun" / "skippedProtected" / "failed".
    public let status: String

    public init(
        timestamp: Date,
        itemId: String,
        moduleId: String?,
        method: String,
        bytesReclaimed: Int64,
        status: String
    ) {
        self.timestamp = timestamp
        self.itemId = itemId
        self.moduleId = moduleId
        self.method = method
        self.bytesReclaimed = bytesReclaimed
        self.status = status
    }
}
