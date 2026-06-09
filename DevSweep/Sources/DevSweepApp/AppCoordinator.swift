import Foundation
import DevSweepCore

/// Thread-safe holder for the last-scan timestamp. The watcher reads it from a background
/// scheduler queue while the coordinator writes it on the main actor; an `NSLock` keeps the
/// single `Date?` consistent without forcing the watcher to hop actors for one value.
///
/// Provides atomic read and atomic write of a single `Date?`; it does NOT make read-modify-write
/// (`box.date = box.date + delta`) compound-atomic. Safe here because the only writer (`apply()`,
/// main actor) and the only reader (the watcher closure, scheduler queue) each perform a single,
/// independent access — never a load-then-store.
final class AtomicDate: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Date?

    var date: Date? {
        get { lock.lock(); defer { lock.unlock() }; return value }
        set { lock.lock(); defer { lock.unlock() }; value = newValue }
    }
}

/// Owns the live object graph — registry-backed scan/persist (`ScanCoordinator`), the scan/notify
/// policies, reclaim routing (`ReclaimRouter`), the `WatcherService`, and the `NotifierService` —
/// and publishes the menubar's view state. Everything user-visible flows through the `@Published`
/// properties; `@MainActor` so SwiftUI and the AppKit status item observe it safely.
@MainActor
final class AppCoordinator: ObservableObject {
    /// One module row for the menu's "top modules" list. `name` is the human display name; the
    /// `module` id is retained for stable identity and routing.
    struct TopModule: Identifiable, Equatable {
        let module: String
        let name: String
        let bytes: Int64
        var id: String { module }
    }

    @Published private(set) var reclaimableBytes: Int64 = 0
    @Published private(set) var topModules: [TopModule] = []
    @Published private(set) var lastScanDate: Date?
    @Published private(set) var isScanning = false
    @Published private(set) var isReclaiming = false

    /// Currently selected menubar skin id. SwiftUI (`MenuView`) observes this directly; the AppKit
    /// status item is pushed updates via `onSkinChange`. Free skins are always selectable; paid skins
    /// only once owned (gated by `skinStore.canSelect`).
    @Published private(set) var currentSkinId: String = SkinCatalog.defaultSkinId

    /// IAP state: loaded products, unlocked-skin set, buy/restore. The menu observes it directly; the
    /// coordinator consults it to gate skin selection. The real `StoreKit2Backend` is injected here.
    let skinStore: SkinStore

    /// Persisted skin id awaiting an entitlements load — a persisted *paid* skin can't be validated
    /// until `skinStore.load()` resolves ownership, so it's re-applied in `reconcileSkinSelection`.
    private var pendingSkinId: String?

    /// `true` once the initial entitlements load has completed. Gates the refund-revert branch so a
    /// transient empty read (e.g. a `Transaction.updates` tick before the first load) can't strip a
    /// still-owned paid skin.
    private var didLoadEntitlements = false

    /// Pure decision logic for re-applying a persisted paid skin / reverting a refunded one.
    private let skinReconciler = SkinSelectionReconciler()

    /// Free skin ids, precomputed for the reconciler (free skins are always selectable).
    private static let freeSkinIds = Set(SkinCatalog.free.map(\.id))

    /// Production purchase backend — one stateless instance shared by `skinStore` and the
    /// `Transaction.updates` observer.
    private let purchaseBackend = StoreKit2Backend()

    /// Long-lived `Transaction.updates` listener (Ask-to-Buy, family sharing, other devices).
    private var transactionObserver: Task<Void, Never>?

    /// UserDefaults key for the persisted skin selection.
    private static let skinDefaultsKey = "DevSweep.currentSkinId"

    /// Latest scan's candidate items, retained for the menu's review/approve reclaim action.
    private(set) var currentItems: [CleanupItem] = []

    /// Latest scan's candidates grouped by owning module id, so reclaim routes by the
    /// authoritative module (not by parsing item ids — node_modules ids are raw paths).
    private var currentGrouped: [(module: String, items: [CleanupItem])] = []

    /// Indicator thresholds + scan/notify tuning. Internal so the status item can colour the gauge.
    let config: AppConfig

    /// Fired on the main actor whenever `reclaimableBytes` changes, so the AppKit status item
    /// (not a SwiftUI view) can re-render its title/tint.
    var onStateChange: ((Int64) -> Void)?

    /// Fired on the main actor when the user picks a different skin, so the AppKit status item can
    /// swap its rendered image (SwiftUI observes `currentSkinId` directly).
    var onSkinChange: ((String) -> Void)?

    private let store: any Store
    private let scanCoordinator: ScanCoordinator
    private let reclaimRouter: ReclaimRouter
    private let notifier: NotifierService
    private let trend = TrendCalculator()
    private let lastScanBox = AtomicDate()
    /// Module id → human display name, for the menu's top-modules list.
    private let moduleNames: [String: String]
    private var watcher: WatcherService?

    private var lastNotifiedBand = 0
    private var lastNotifiedAt: Date?
    /// Set when a scan is requested while one is in flight, so the in-flight scan re-runs once
    /// more before settling — guarantees the post-reclaim re-scan is never silently dropped.
    private var rescanPending = false

    init(config: AppConfig = .default) {
        self.config = config
        self.skinStore = SkinStore(backend: purchaseBackend)

        // Restore the persisted skin selection. A free skin applies immediately; a persisted *paid*
        // skin is held in `pendingSkinId` and re-applied (or reverted) once entitlements load.
        let persisted = UserDefaults.standard.string(forKey: Self.skinDefaultsKey)
        self.pendingSkinId = persisted
        if let persisted, SkinCatalog.skin(id: persisted)?.isFree == true {
            currentSkinId = persisted
        }

        // One shared module set drives both scanning (registry) and reclaim routing (router).
        let modules = DefaultDetectorRegistry.makeModules(deleter: TrashingFileSystemDeleter())
        self.moduleNames = Dictionary(modules.map { ($0.id, $0.displayName) }, uniquingKeysWith: { first, _ in first })
        let registry = DetectorRegistry(modules: modules)
        let store = AppCoordinator.makeStore()
        self.store = store
        self.scanCoordinator = ScanCoordinator(
            registry: registry,
            store: store,
            idProvider: { UUID().uuidString },
            now: { Date() }
        )
        self.reclaimRouter = ReclaimRouter(modules: modules, store: store, now: { Date() })
        self.notifier = NotifierService(config: config)
    }

    /// Build the SQLite store under Application Support; fall back to in-memory so a bad path or a
    /// sandbox restriction never crashes the app (history simply isn't persisted in that case).
    private static func makeStore() -> any Store {
        let fileManager = FileManager.default
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        let dir = base.appendingPathComponent("DevSweep", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        let dbPath = dir.appendingPathComponent("devsweep.sqlite").path
        if let store = try? SQLiteStore(path: dbPath) {
            return store
        }
        return InMemoryStore()
    }

    /// Request notification permission (no-op outside a real `.app` bundle), start the watcher,
    /// and run one initial scan so the indicator reflects reality at launch.
    func start() {
        notifier.requestAuthorizationIfPossible()

        // Load IAP products + entitlements, then reconcile the persisted skin selection against what
        // the user actually owns (re-apply a persisted paid skin; revert a refunded one). The
        // `didLoadEntitlements` flag is set before reconciling so the revert branch is now armed.
        Task { [weak self] in
            await self?.skinStore.load()
            self?.didLoadEntitlements = true
            self?.reconcileSkinSelection()
        }
        // React to transactions completed outside an explicit buy (Ask-to-Buy, family sharing, other
        // devices) so an external unlock/refund is reflected without a relaunch.
        transactionObserver = purchaseBackend.observeTransactionUpdates { [weak self] in
            await self?.handleEntitlementChange()
        }

        let watcher = WatcherService(
            config: config,
            probe: StatfsDiskSpaceProbe(),
            lastScanProvider: { [box = lastScanBox] in box.date },
            onTrigger: { [weak self] trigger in await self?.handleTrigger(trigger) }
        )
        self.watcher = watcher
        watcher.start()

        Task { await self.scanNow() }
    }

    /// User pressed "Scan now" in the menu — force a manual trigger through the watcher/policy.
    func requestManualScan() {
        watcher?.triggerManual()
    }

    /// Select a menubar skin. Free skins are always allowed; paid skins only when unlocked
    /// (`skinStore.canSelect`). Unknown or still-locked ids are ignored. Persists + notifies.
    func setSkin(id: String) {
        guard id != currentSkinId,
              let skin = SkinCatalog.skin(id: id),
              skinStore.canSelect(skin) else { return }
        currentSkinId = id
        UserDefaults.standard.set(id, forKey: Self.skinDefaultsKey)
        onSkinChange?(id)
    }

    /// Reconcile the selected skin against current entitlements via the pure `SkinSelectionReconciler`.
    /// Runs after the initial load and on every external transaction update: re-applies a persisted
    /// paid skin once it's owned (consuming `pendingSkinId` only then — so a concurrent early tick
    /// can't discard it), and reverts a no-longer-owned paid skin to the default (refund /
    /// family-sharing loss), gated on `didLoadEntitlements`. Free skins are never affected.
    private func reconcileSkinSelection() {
        let decision = skinReconciler.reconcile(
            currentSelection: currentSkinId,
            pendingSelection: pendingSkinId,
            freeSkinIds: Self.freeSkinIds,
            unlockedSkinIds: skinStore.unlockedSkinIds,
            didLoadEntitlements: didLoadEntitlements,
            defaultSkinId: SkinCatalog.defaultSkinId
        )
        if decision.clearedPending {
            pendingSkinId = nil
        }
        if decision.selection != currentSkinId {
            currentSkinId = decision.selection
            UserDefaults.standard.set(currentSkinId, forKey: Self.skinDefaultsKey)
            onSkinChange?(currentSkinId)
        }
    }

    /// An external transaction changed ownership — refresh the unlocked set and reconcile selection.
    private func handleEntitlementChange() async {
        await skinStore.refresh()
        reconcileSkinSelection()
    }

    /// All triggers currently resolve to a full scan; the reason is retained for future routing.
    func handleTrigger(_ trigger: ScanTrigger) async {
        await scanNow()
    }

    /// Scan all available modules, persist the snapshot, refresh published state, and notify.
    /// Reentrancy-safe: a scan requested while one is in flight is coalesced (the in-flight scan
    /// re-runs once more) rather than dropped, so a watcher trigger can't shadow a post-reclaim
    /// refresh.
    func scanNow() async {
        if isScanning {
            rescanPending = true
            return
        }
        isScanning = true
        repeat {
            rescanPending = false
            // The recursive DirectorySizer `du` over tens of GB of node_modules is heavy and
            // synchronous. AppCoordinator is @MainActor, so running the scan inline here pins that
            // du to the main thread and freezes the run loop (the menubar title stays "0 bytes",
            // the scan never settles). Offload it onto a detached background task; we hop back to
            // the main actor only to publish the result.
            let coordinator = scanCoordinator // Sendable struct captured by the detached task
            let result = await Task.detached(priority: .utility) {
                await coordinator.runScanDetailed()
            }.value
            currentGrouped = result.grouped
            currentItems = result.grouped.flatMap(\.items)
            apply(record: result.record)
        } while rescanPending
        isScanning = false
    }

    /// Route approved items to their owning modules and reclaim them (honoring `dryRun`); after a
    /// real reclaim, re-scan so the indicator reflects the freed space. Routing uses the current
    /// scan's module grouping (not item-id prefixes), so path-id modules (node_modules) reclaim
    /// correctly. Guarded against concurrent passes so a double-tap can't fire two reclaims.
    @discardableResult
    func reclaim(approved items: [CleanupItem], dryRun: Bool) async -> [ReclaimOutcome] {
        guard !isReclaiming else { return [] }
        isReclaiming = true
        defer { isReclaiming = false }

        let approvedIds = Set(items.map(\.id))
        let grouped = currentGrouped
            .map { (module: $0.module, items: $0.items.filter { approvedIds.contains($0.id) }) }
            .filter { !$0.items.isEmpty }

        let outcomes = await reclaimRouter.reclaim(grouped: grouped, dryRun: dryRun)
        if !dryRun {
            await scanNow()
        }
        return outcomes
    }

    private func apply(record: ScanRecord) {
        reclaimableBytes = record.totalBytes
        topModules = trend.topModules(record, limit: 5)
            .map { TopModule(module: $0.module, name: moduleNames[$0.module] ?? $0.module, bytes: $0.bytes) }
        lastScanDate = record.timestamp
        lastScanBox.date = record.timestamp

        let decision = notifier.notifyIfNeeded(
            reclaimableBytes: record.totalBytes,
            lastNotifiedBand: lastNotifiedBand,
            lastNotifiedAt: lastNotifiedAt,
            now: Date()
        )
        lastNotifiedBand = decision.band
        if decision.shouldNotify {
            lastNotifiedAt = Date()
        }

        onStateChange?(reclaimableBytes)
    }
}
