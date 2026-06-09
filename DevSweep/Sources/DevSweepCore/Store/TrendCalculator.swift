import Foundation

/// Pure, stateless trend math over a list of `ScanRecord`s. Input order does not matter;
/// every query resolves "latest" by `timestamp`.
public struct TrendCalculator: Sendable {
    public init() {}

    /// Total reclaimable bytes from the most recent scan; 0 when there are no scans.
    public func currentTotal(_ scans: [ScanRecord]) -> Int64 {
        latest(scans)?.totalBytes ?? 0
    }

    /// Change in total since `since`: latest total minus the total of the most recent scan
    /// at or before `since`. If no scan precedes `since`, the baseline is 0.
    public func delta(_ scans: [ScanRecord], since: Date) -> Int64 {
        let baseline = scans
            .filter { $0.timestamp <= since }
            .max { $0.timestamp < $1.timestamp }?
            .totalBytes ?? 0
        return currentTotal(scans) - baseline
    }

    /// Modules of one scan ranked by reclaimable bytes descending (ties broken by module id
    /// ascending for determinism), truncated to `limit`.
    public func topModules(_ scan: ScanRecord, limit: Int) -> [(module: String, bytes: Int64)] {
        scan.perModule
            .sorted { lhs, rhs in lhs.value != rhs.value ? lhs.value > rhs.value : lhs.key < rhs.key }
            .prefix(max(0, limit))
            .map { (module: $0.key, bytes: $0.value) }
    }

    /// True when the latest scan's total strictly exceeds the previous one's. Fewer than two
    /// scans → false.
    public func isGrowing(_ scans: [ScanRecord]) -> Bool {
        let recent = scans.sorted { $0.timestamp > $1.timestamp }
        guard recent.count >= 2 else { return false }
        return recent[0].totalBytes > recent[1].totalBytes
    }

    private func latest(_ scans: [ScanRecord]) -> ScanRecord? {
        scans.max { $0.timestamp < $1.timestamp }
    }
}
