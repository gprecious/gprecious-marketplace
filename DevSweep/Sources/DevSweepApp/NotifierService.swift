import Foundation
import UserNotifications
import DevSweepCore

/// Threshold notifications. Delegates the *decision* to the unit-tested `NotificationPolicy`
/// (band transition + daily throttle) and only performs the side effect — posting a
/// `UNUserNotificationCenter` alert with three actions: review / safe-cache-clean / stop-today.
///
/// Headless / non-bundled safety: `UNUserNotificationCenter.current()` traps in an executable
/// with no bundle proxy (`swift run`, no Info.plist). Every center access is gated behind a real
/// bundle identifier, so on the smoke path the notifier is an inert no-op — it never throws and
/// never crashes. Used only from the main actor (`AppCoordinator`).
final class NotifierService {
    enum ActionID {
        static let review = "devsweep.action.review"
        static let safeCacheClean = "devsweep.action.safeCacheClean"
        static let stopToday = "devsweep.action.stopToday"
        static let category = "devsweep.category.threshold"
    }

    private let policy: NotificationPolicy
    /// True only inside a real `.app` bundle; gates all `UNUserNotificationCenter` access.
    private let centerAvailable: Bool

    init(config: AppConfig) {
        self.policy = NotificationPolicy(config: config)
        self.centerAvailable = Bundle.main.bundleIdentifier != nil
    }

    /// Register the action category and request alert authorization. No-op outside a bundle.
    ///
    /// The three actions are registered but intentionally have NO `UNUserNotificationCenterDelegate`
    /// wired this milestone, so tapping them is inert — there is deliberately no notification →
    /// real-reclaim path yet (a posted notification can never trigger a delete). When the handler
    /// lands in M6 it must route `safeCacheClean` through `AppCoordinator.reclaim(approved:dryRun:)`
    /// (Reclaimer's protected-skip + dry-run gates), never a one-tap shortcut delete.
    func requestAuthorizationIfPossible() {
        guard centerAvailable else { return }
        let center = UNUserNotificationCenter.current()

        let review = UNNotificationAction(identifier: ActionID.review, title: "리뷰", options: [.foreground])
        let safe = UNNotificationAction(identifier: ActionID.safeCacheClean, title: "안전 캐시 정리", options: [])
        let stop = UNNotificationAction(identifier: ActionID.stopToday, title: "오늘 그만", options: [])
        let category = UNNotificationCategory(
            identifier: ActionID.category,
            actions: [review, safe, stop],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Ask the policy; on a positive decision post a notification (when a center is available).
    /// Returns the decision so the caller can persist `lastNotifiedBand` / `lastNotifiedAt`.
    @discardableResult
    func notifyIfNeeded(
        reclaimableBytes: Int64,
        lastNotifiedBand: Int,
        lastNotifiedAt: Date?,
        now: Date
    ) -> NotificationDecision {
        let decision = policy.evaluate(
            reclaimableBytes: reclaimableBytes,
            lastNotifiedBand: lastNotifiedBand,
            lastNotifiedAt: lastNotifiedAt,
            now: now
        )
        guard centerAvailable, decision.shouldNotify else { return decision }
        post(reclaimableBytes: reclaimableBytes)
        return decision
    }

    private func post(reclaimableBytes: Int64) {
        guard centerAvailable else { return } // self-protecting: never touch .current() unbundled
        let content = UNMutableNotificationContent()
        content.title = "DevSweep"
        content.body = "회수 가능한 공간이 \(humanBytes(reclaimableBytes)) 쌓였습니다."
        content.categoryIdentifier = ActionID.category
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
