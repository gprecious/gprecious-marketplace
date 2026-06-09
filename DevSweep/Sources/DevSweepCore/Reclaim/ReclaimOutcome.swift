/// What happened to one candidate during a reclaim pass.
public enum ReclaimStatus: Sendable, Equatable {
    /// Safety Layer downgraded it to `.protected`; not touched.
    case skippedProtected
    /// Dry-run: would have reclaimed this many bytes.
    case dryRun(plannedBytes: Int64)
    /// Actually deleted; bytes reclaimed as reported by the deleter.
    case deleted(bytes: Int64)
    /// Deletion attempted but failed.
    case failed(message: String)
}

public struct ReclaimOutcome: Sendable, Equatable {
    public let item: CleanupItem
    public let status: ReclaimStatus

    public init(item: CleanupItem, status: ReclaimStatus) {
        self.item = item
        self.status = status
    }
}
