import Testing
@testable import DevSweepCore

/// Test double for `PurchaseBackend`. An `actor` so its mutable owned-set + call log are
/// concurrency-safe (the protocol is `Sendable`; `SkinStore` is `@MainActor` and awaits it across
/// the actor boundary). Configure outcomes via init: `owned` seeds existing entitlements,
/// `purchaseSucceeds` toggles cancel/failure, `restoreAdds` is the set a restore "finds".
///
/// `revoke` shrinks the owned set to simulate an App Store refund/revocation. `holdPurchase` makes
/// `purchase` block until `releasePurchase()`, with `waitUntilPurchaseStarted()` to deterministically
/// observe the in-flight window (used to test the reentrancy guard).
actor MockPurchaseBackend: PurchaseBackend {
    private var owned: Set<String>
    private let available: [IAPProduct]
    private let purchaseSucceeds: Bool
    private let restoreAdds: Set<String>
    private let holdPurchase: Bool

    /// Calls recorded for assertions.
    private(set) var purchaseCalls: [String] = []
    private(set) var restoreCalls = 0
    private(set) var loadCalls = 0

    // Gate plumbing for the in-flight reentrancy test.
    private var purchaseDidStart = false
    private var startedContinuation: CheckedContinuation<Void, Never>?
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    init(
        owned: Set<String> = [],
        available: [IAPProduct] = ProductCatalog.all,
        purchaseSucceeds: Bool = true,
        restoreAdds: Set<String> = [],
        holdPurchase: Bool = false
    ) {
        self.owned = owned
        self.available = available
        self.purchaseSucceeds = purchaseSucceeds
        self.restoreAdds = restoreAdds
        self.holdPurchase = holdPurchase
    }

    func loadProducts(ids: [String]) async throws -> [IAPProduct] {
        loadCalls += 1
        let requested = Set(ids)
        return available.filter { requested.contains($0.id) }
    }

    func purchase(id: String) async throws -> Bool {
        purchaseCalls.append(id)
        if holdPurchase {
            purchaseDidStart = true
            startedContinuation?.resume()
            startedContinuation = nil
            await withCheckedContinuation { releaseContinuation = $0 }
        }
        guard purchaseSucceeds else { return false }
        owned.insert(id)
        return true
    }

    func currentEntitlementIds() async -> Set<String> {
        owned
    }

    func restore() async throws {
        restoreCalls += 1
        owned.formUnion(restoreAdds)
    }

    // MARK: - Test controls

    /// Simulate an App Store refund/revocation: the product is no longer owned.
    func revoke(_ id: String) {
        owned.remove(id)
    }

    /// Suspends until a gated `purchase` has entered its in-flight window.
    func waitUntilPurchaseStarted() async {
        if purchaseDidStart { return }
        await withCheckedContinuation { startedContinuation = $0 }
    }

    /// Releases a gated `purchase` so it can complete.
    func releasePurchase() {
        releaseContinuation?.resume()
        releaseContinuation = nil
    }
}
