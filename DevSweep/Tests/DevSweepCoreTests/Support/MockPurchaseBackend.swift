import Testing
@testable import DevSweepCore

/// Test double for `PurchaseBackend`. An `actor` so its mutable owned-set + call log are
/// concurrency-safe (the protocol is `Sendable`; `SkinStore` is `@MainActor` and awaits it across
/// the actor boundary). Configure outcomes via init: `owned` seeds existing entitlements,
/// `purchaseSucceeds` toggles cancel/failure, `restoreAdds` is the set a restore "finds".
actor MockPurchaseBackend: PurchaseBackend {
    private var owned: Set<String>
    private let available: [IAPProduct]
    private let purchaseSucceeds: Bool
    private let restoreAdds: Set<String>

    /// Calls recorded for assertions.
    private(set) var purchaseCalls: [String] = []
    private(set) var restoreCalls = 0
    private(set) var loadCalls = 0

    init(
        owned: Set<String> = [],
        available: [IAPProduct] = ProductCatalog.all,
        purchaseSucceeds: Bool = true,
        restoreAdds: Set<String> = []
    ) {
        self.owned = owned
        self.available = available
        self.purchaseSucceeds = purchaseSucceeds
        self.restoreAdds = restoreAdds
    }

    func loadProducts(ids: [String]) async throws -> [IAPProduct] {
        loadCalls += 1
        let requested = Set(ids)
        return available.filter { requested.contains($0.id) }
    }

    func purchase(id: String) async throws -> Bool {
        purchaseCalls.append(id)
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
}
