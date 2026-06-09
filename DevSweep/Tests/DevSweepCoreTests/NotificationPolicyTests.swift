import Foundation
import Testing
@testable import DevSweepCore

private let config = AppConfig(
    scanInterval: 1,
    diskPressurePct: 0.1,
    notifyThresholdBytes: 20,
    gaugeLowBytes: 5,
    gaugeHighBytes: 99
)

private let now = Date(timeIntervalSince1970: 1_000_000)

@Test func notificationPolicyMapsReclaimableBytesToConfiguredBands() {
    let policy = NotificationPolicy(config: config)

    #expect(policy.evaluate(reclaimableBytes: 4, lastNotifiedBand: 0, lastNotifiedAt: now, now: now).band == 0)
    #expect(policy.evaluate(reclaimableBytes: 5, lastNotifiedBand: 0, lastNotifiedAt: now, now: now).band == 1)
    #expect(policy.evaluate(reclaimableBytes: 19, lastNotifiedBand: 0, lastNotifiedAt: now, now: now).band == 1)
    #expect(policy.evaluate(reclaimableBytes: 20, lastNotifiedBand: 0, lastNotifiedAt: now, now: now).band == 2)
}

@Test func notificationPolicyNotifiesOnUpwardBandTransitionEvenWhenRecentlyNotified() {
    let policy = NotificationPolicy(config: config)
    let recent = now.addingTimeInterval(-60)

    let decision = policy.evaluate(
        reclaimableBytes: 20,
        lastNotifiedBand: 1,
        lastNotifiedAt: recent,
        now: now
    )

    #expect(decision == NotificationDecision(shouldNotify: true, band: 2))
}

@Test func notificationPolicyDoesNotNotifyOnDownwardBandTransition() {
    let policy = NotificationPolicy(config: config)

    let decision = policy.evaluate(
        reclaimableBytes: 6,
        lastNotifiedBand: 2,
        lastNotifiedAt: now.addingTimeInterval(-25 * 3600),
        now: now
    )

    #expect(decision == NotificationDecision(shouldNotify: false, band: 1))
}

@Test func notificationPolicyThrottlesSameBandUntilTwentyFourHoursHaveElapsed() {
    let policy = NotificationPolicy(config: config)

    let decision = policy.evaluate(
        reclaimableBytes: 20,
        lastNotifiedBand: 2,
        lastNotifiedAt: now.addingTimeInterval(-(24 * 3600) + 1),
        now: now
    )

    #expect(decision == NotificationDecision(shouldNotify: false, band: 2))
}

@Test func notificationPolicyAllowsSameBandNotificationAtTwentyFourHourBoundary() {
    let policy = NotificationPolicy(config: config)

    let decision = policy.evaluate(
        reclaimableBytes: 20,
        lastNotifiedBand: 2,
        lastNotifiedAt: now.addingTimeInterval(-24 * 3600),
        now: now
    )

    #expect(decision == NotificationDecision(shouldNotify: true, band: 2))
}

@Test func notificationPolicyAllowsSameBandNotificationAfterTwentyFourHours() {
    let policy = NotificationPolicy(config: config)

    let decision = policy.evaluate(
        reclaimableBytes: 20,
        lastNotifiedBand: 2,
        lastNotifiedAt: now.addingTimeInterval(-(24 * 3600) - 1),
        now: now
    )

    #expect(decision == NotificationDecision(shouldNotify: true, band: 2))
}

@Test func notificationPolicyNotifiesWhenSameBandHasNeverBeenNotifiedAt() {
    let policy = NotificationPolicy(config: config)

    let decision = policy.evaluate(
        reclaimableBytes: 20,
        lastNotifiedBand: 2,
        lastNotifiedAt: nil,
        now: now
    )

    #expect(decision == NotificationDecision(shouldNotify: true, band: 2))
}
