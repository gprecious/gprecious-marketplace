import Foundation
import DevSweepCore

/// Periodic + manual scan trigger. Wraps `NSBackgroundActivityScheduler` for energy-friendly
/// wakeups; on each wake (and on a manual request) it snapshots the disk and asks the
/// unit-tested `ScanTriggerPolicy` whether a scan is due, invoking the async `onTrigger`
/// callback with the reason when it is. Pure scheduling glue — no decision logic of its own.
///
/// `@unchecked Sendable`: the only stored mutable object is the scheduler, configured once in
/// `init` and thereafter only read; all closures are `@Sendable` and the probe/policy are value
/// types, so concurrent reads from the background scheduler queue are safe.
final class WatcherService: @unchecked Sendable {
    private let probe: any DiskSpaceProbe
    private let policy: ScanTriggerPolicy
    private let lastScanProvider: @Sendable () -> Date?
    private let clock: @Sendable () -> Date
    private let onTrigger: @Sendable (ScanTrigger) async -> Void
    private let scheduler: NSBackgroundActivityScheduler

    init(
        config: AppConfig,
        probe: any DiskSpaceProbe,
        lastScanProvider: @escaping @Sendable () -> Date?,
        clock: @escaping @Sendable () -> Date = { Date() },
        onTrigger: @escaping @Sendable (ScanTrigger) async -> Void
    ) {
        self.probe = probe
        self.policy = ScanTriggerPolicy(config: config)
        self.lastScanProvider = lastScanProvider
        self.clock = clock
        self.onTrigger = onTrigger

        let scheduler = NSBackgroundActivityScheduler(identifier: "com.flow-finders.devsweep.watcher")
        scheduler.repeats = true
        scheduler.interval = config.scanInterval
        scheduler.tolerance = min(config.scanInterval * 0.1, 30 * 60)
        scheduler.qualityOfService = .utility
        self.scheduler = scheduler
    }

    /// Begin periodic wakeups. The first interval elapses before the first automatic check, so
    /// launch itself does not trigger a scan here (the coordinator runs one explicit initial scan).
    func start() {
        scheduler.schedule { [weak self] completion in
            self?.evaluate(manualRequested: false)
            completion(.finished)
        }
    }

    /// User pressed "Scan now" — always yields `.manual`, bypassing the interval/pressure checks.
    func triggerManual() {
        evaluate(manualRequested: true)
    }

    func invalidate() {
        scheduler.invalidate()
    }

    private func evaluate(manualRequested: Bool) {
        let trigger = policy.evaluate(
            lastScan: lastScanProvider(),
            now: clock(),
            disk: probe.snapshot(),
            manualRequested: manualRequested
        )
        guard trigger != .none else { return }
        let onTrigger = self.onTrigger
        Task { await onTrigger(trigger) }
    }
}
