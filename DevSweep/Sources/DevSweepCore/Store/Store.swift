/// Append-only persistence for scan history and reclaim audit entries. The Store never
/// deletes anything on disk — it only records what scans found and what reclaim did.
/// Reads return newest-first (timestamp descending), bounded by `limit`.
public protocol Store: Sendable {
    /// Persist one scan snapshot.
    func recordScan(_ record: ScanRecord) async
    /// Append a batch of audit entries (one reclaim pass).
    func recordAudit(_ records: [AuditRecord]) async
    /// Up to `limit` most recent scans, newest first.
    func recentScans(limit: Int) async -> [ScanRecord]
    /// Up to `limit` most recent audit entries, newest first.
    func auditLog(limit: Int) async -> [AuditRecord]
    /// The single most recent scan, or `nil` when no scans recorded.
    func latestScan() async -> ScanRecord?
}
