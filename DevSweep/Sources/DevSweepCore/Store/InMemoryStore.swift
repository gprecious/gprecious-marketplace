/// Default, non-persistent `Store`. Accumulates records in memory; reads sort by
/// timestamp descending and apply the limit. The `actor` serializes all mutation, so it
/// is safe to share across concurrent scan/reclaim tasks.
public actor InMemoryStore: Store {
    private var scans: [ScanRecord] = []
    private var audits: [AuditRecord] = []

    public init() {}

    public func recordScan(_ record: ScanRecord) async {
        scans.append(record)
    }

    public func recordAudit(_ records: [AuditRecord]) async {
        audits.append(contentsOf: records)
    }

    public func recentScans(limit: Int) async -> [ScanRecord] {
        Array(scans.sorted { $0.timestamp > $1.timestamp }.prefix(max(0, limit)))
    }

    public func auditLog(limit: Int) async -> [AuditRecord] {
        Array(audits.sorted { $0.timestamp > $1.timestamp }.prefix(max(0, limit)))
    }

    public func latestScan() async -> ScanRecord? {
        scans.max { $0.timestamp < $1.timestamp }
    }
}
