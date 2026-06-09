import Foundation

/// Tunable thresholds for the menubar app's scan/notify/indicator behavior. Bytes are
/// decimal GB (1 GB = 1_000_000_000) to match how disk sizes are reported to users.
public struct AppConfig: Sendable, Equatable {
    /// Minimum interval between automatic interval-triggered scans.
    public var scanInterval: TimeInterval
    /// Free/total ratio below which disk pressure forces a scan (0.15 = under 15% free).
    public var diskPressurePct: Double
    /// Reclaimable total at/above which the user is notified.
    public var notifyThresholdBytes: Int64
    /// Indicator gauge low edge — below this reads as "low".
    public var gaugeLowBytes: Int64
    /// Indicator gauge high edge — at/above this reads as "high".
    public var gaugeHighBytes: Int64

    public init(
        scanInterval: TimeInterval = 6 * 3600,
        diskPressurePct: Double = 0.15,
        notifyThresholdBytes: Int64 = 20_000_000_000,
        gaugeLowBytes: Int64 = 5_000_000_000,
        gaugeHighBytes: Int64 = 20_000_000_000
    ) {
        self.scanInterval = scanInterval
        self.diskPressurePct = diskPressurePct
        self.notifyThresholdBytes = notifyThresholdBytes
        self.gaugeLowBytes = gaugeLowBytes
        self.gaugeHighBytes = gaugeHighBytes
    }

    public static let `default` = AppConfig()
}
