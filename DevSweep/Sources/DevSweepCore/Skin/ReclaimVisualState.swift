import Foundation

/// Pure mapping from a reclaimable-byte total to the visual state a menubar skin draws.
///
/// The band/critical semantics match the rest of the app (`NotificationPolicy`, `StatusIndicator`):
/// `< low` → band 0, `low ..< high` → band 1, `>= high` → band 2 (critical). `fillRatio` is the
/// total clamped against `high` into the unit interval so a skin can fill proportionally. No AppKit
/// dependency — this is the testable core of the indicator; the drawing skins consume it.
public struct ReclaimVisualState: Sendable, Equatable {
    /// Discrete pressure band — `0:< low`, `1: low ..< high`, `2: >= high`.
    public let band: Int
    /// `bytes / high`, clamped to `0...1`. Drives proportional fills (gauge level, lit dots, …).
    public let fillRatio: Double
    /// `true` exactly when in the top band — skins use it to escalate emphasis (red/glow).
    public let isCritical: Bool

    /// - Parameters:
    ///   - reclaimableBytes: total reclaimable bytes; negatives are floored to 0.
    ///   - low: lower band edge (`< low` reads as band 0).
    ///   - high: upper band edge (`>= high` reads as band 2 / critical); also the fill denominator.
    public init(reclaimableBytes: Int64, low: Int64, high: Int64) {
        let bytes = max(0, reclaimableBytes)

        let resolvedBand: Int
        if bytes < low {
            resolvedBand = 0
        } else if bytes < high {
            resolvedBand = 1
        } else {
            resolvedBand = 2
        }
        self.band = resolvedBand
        self.isCritical = resolvedBand == 2

        // Guard a misconfigured / zero `high` so the ratio never divides by zero.
        let denominator = Double(max(1, high))
        self.fillRatio = min(max(Double(bytes) / denominator, 0.0), 1.0)
    }
}

extension ReclaimVisualState {
    /// Convenience over an `AppConfig`, using its gauge thresholds.
    public init(reclaimableBytes: Int64, config: AppConfig) {
        self.init(reclaimableBytes: reclaimableBytes, low: config.gaugeLowBytes, high: config.gaugeHighBytes)
    }
}
