import Foundation

public struct NotificationDecision: Sendable, Equatable {
    public let shouldNotify: Bool
    public let band: Int

    public init(shouldNotify: Bool, band: Int) {
        self.shouldNotify = shouldNotify
        self.band = band
    }
}

public struct NotificationPolicy: Sendable {
    private let config: AppConfig
    private static let throttleInterval: TimeInterval = 24 * 3600

    public init(config: AppConfig) {
        self.config = config
    }

    public func evaluate(
        reclaimableBytes: Int64,
        lastNotifiedBand: Int,
        lastNotifiedAt: Date?,
        now: Date
    ) -> NotificationDecision {
        let band = band(for: reclaimableBytes)

        if band > lastNotifiedBand {
            return NotificationDecision(shouldNotify: true, band: band)
        }

        guard band == lastNotifiedBand else {
            return NotificationDecision(shouldNotify: false, band: band)
        }

        guard let lastNotifiedAt else {
            return NotificationDecision(shouldNotify: true, band: band)
        }

        let elapsed = now.timeIntervalSince(lastNotifiedAt)
        return NotificationDecision(
            shouldNotify: elapsed >= Self.throttleInterval,
            band: band
        )
    }

    private func band(for reclaimableBytes: Int64) -> Int {
        if reclaimableBytes < config.gaugeLowBytes {
            return 0
        }

        if reclaimableBytes < config.notifyThresholdBytes {
            return 1
        }

        return 2
    }
}
