import Foundation

public extension ScanRecord {
    /// Build a snapshot from `DetectorRegistry.scanGrouped()` output. Each module's
    /// reclaimable bytes is the sum of its items' `sizeBytes`.
    init(id: String, timestamp: Date, from grouped: [(module: String, items: [CleanupItem])]) {
        var per: [String: Int64] = [:]
        for group in grouped {
            per[group.module, default: 0] += group.items.reduce(0) { $0 + $1.sizeBytes }
        }
        self.init(id: id, timestamp: timestamp, perModule: per)
    }
}

public extension ReclaimMethod {
    /// Audit-log description, e.g. "deletePath(trash:false)" /
    /// "cliCommand(docker builder prune -f)".
    var auditDescription: String {
        switch self {
        case .deletePath(let toTrash):
            return "deletePath(trash:\(toTrash))"
        case .cliCommand(let executable, let arguments):
            return "cliCommand(\(([executable] + arguments).joined(separator: " ")))"
        }
    }
}

/// Pure builders translating live scan/reclaim results into persistable records.
public enum StoreBuilders {
    /// Map a reclaim pass to audit entries — one per outcome, input order preserved.
    public static func auditRecords(timestamp: Date, from outcomes: [ReclaimOutcome]) -> [AuditRecord] {
        outcomes.map { outcome in
            let (status, bytes) = statusAndBytes(outcome.status)
            return AuditRecord(
                timestamp: timestamp,
                itemId: outcome.item.id,
                moduleId: moduleId(fromItemId: outcome.item.id),
                method: outcome.item.reclaimMethod.auditDescription,
                bytesReclaimed: bytes,
                status: status
            )
        }
    }

    /// ReclaimStatus → (status string, recorded bytes). `deleted`/`dryRun` carry their bytes;
    /// `skippedProtected`/`failed` record 0.
    private static func statusAndBytes(_ status: ReclaimStatus) -> (String, Int64) {
        switch status {
        case .deleted(let bytes):  return ("deleted", bytes)
        case .dryRun(let planned): return ("dryRun", planned)
        case .skippedProtected:    return ("skippedProtected", 0)
        case .failed:              return ("failed", 0)
        }
    }

    /// Module id = the token before the first ":" in an item id ("docker:build-cache" →
    /// "docker"). Filesystem paths (which contain "/") have no module prefix → nil.
    static func moduleId(fromItemId id: String) -> String? {
        guard let colon = id.firstIndex(of: ":") else { return nil }
        let prefix = String(id[..<colon])
        return prefix.contains("/") ? nil : prefix
    }
}
