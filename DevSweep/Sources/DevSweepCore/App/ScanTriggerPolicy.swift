import Foundation

/// Why a scan was triggered (or that none is due). Pure value so the Watcher's
/// decision can be unit-tested against a deterministic clock + disk state.
public enum ScanTrigger: Sendable, Equatable {
    case interval, diskPressure, manual, none
}

/// Decides whether the menubar app should scan now, and why. Stateless: the caller
/// supplies the last-scan timestamp, current time, a disk snapshot, and whether the
/// user pressed "Scan now".
public struct ScanTriggerPolicy: Sendable {
    private let config: AppConfig

    public init(config: AppConfig) {
        self.config = config
    }

    /// Priority: `manual` > `diskPressure` > `interval` > `none`.
    /// - `manualRequested` → `.manual`.
    /// - free/total strictly below `config.diskPressurePct` → `.diskPressure`
    ///   (a non-positive total can't be under pressure and is skipped, avoiding /0).
    /// - no prior scan, or `now - lastScan >= config.scanInterval` → `.interval`.
    /// - otherwise → `.none`.
    public func evaluate(
        lastScan: Date?,
        now: Date,
        disk: (freeBytes: Int64, totalBytes: Int64),
        manualRequested: Bool
    ) -> ScanTrigger {
        if manualRequested { return .manual }

        if disk.totalBytes > 0 {
            let freeRatio = Double(disk.freeBytes) / Double(disk.totalBytes)
            if freeRatio < config.diskPressurePct { return .diskPressure }
        }

        guard let lastScan else { return .interval }
        if now.timeIntervalSince(lastScan) >= config.scanInterval { return .interval }

        return .none
    }
}
