import Testing
@testable import DevSweepCore

/// Contract tests for the test double itself — `MockPurchaseBackend` is the substrate every
/// `SkinStore` test relies on, so its owned-set semantics (purchase adds, restore grants, load
/// filters) must be pinned independently.
@Suite struct PurchaseBackendTests {
    @Test func loadProductsFiltersToRequestedIds() async throws {
        let backend = MockPurchaseBackend()
        let loaded = try await backend.loadProducts(ids: ["kr.qplace.devsweep.skin.dotmatrix"])
        #expect(loaded.map(\.id) == ["kr.qplace.devsweep.skin.dotmatrix"])
    }

    @Test func purchaseAddsToOwnedAndSucceeds() async throws {
        let backend = MockPurchaseBackend()
        let ok = try await backend.purchase(id: "kr.qplace.devsweep.skin.synthwave")
        #expect(ok)
        let owned = await backend.currentEntitlementIds()
        #expect(owned.contains("kr.qplace.devsweep.skin.synthwave"))
    }

    @Test func purchaseFailsWithoutMutatingOwnedWhenConfiguredToFail() async throws {
        let backend = MockPurchaseBackend(purchaseSucceeds: false)
        let ok = try await backend.purchase(id: "kr.qplace.devsweep.skin.synthwave")
        #expect(!ok)
        let owned = await backend.currentEntitlementIds()
        #expect(owned.isEmpty)
    }

    @Test func currentEntitlementsReflectsInjectedOwnedSet() async {
        let backend = MockPurchaseBackend(owned: ["kr.qplace.devsweep.allaccess"])
        let owned = await backend.currentEntitlementIds()
        #expect(owned == ["kr.qplace.devsweep.allaccess"])
    }

    @Test func restoreGrantsPreviouslyOwnedProducts() async throws {
        let backend = MockPurchaseBackend(restoreAdds: ["kr.qplace.devsweep.skin.dotmatrix"])
        try await backend.restore()
        let owned = await backend.currentEntitlementIds()
        #expect(owned.contains("kr.qplace.devsweep.skin.dotmatrix"))
    }

    @Test func recordsPurchaseAndRestoreCalls() async throws {
        let backend = MockPurchaseBackend()
        _ = try await backend.purchase(id: "kr.qplace.devsweep.skin.dotmatrix")
        try await backend.restore()
        let purchases = await backend.purchaseCalls
        let restores = await backend.restoreCalls
        #expect(purchases == ["kr.qplace.devsweep.skin.dotmatrix"])
        #expect(restores == 1)
    }
}
