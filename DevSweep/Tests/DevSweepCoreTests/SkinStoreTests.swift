import Testing
@testable import DevSweepCore

/// `SkinStore` is the `@MainActor` state machine the menu observes: it loads products, drives
/// buy/restore through an injected `PurchaseBackend`, and republishes the unlocked-skin set via
/// `EntitlementResolver`. Driven entirely by `MockPurchaseBackend` so the logic is verified without
/// StoreKit. `canSelect` is the selection gate (free always; paid only when unlocked).
@Suite @MainActor struct SkinStoreTests {
    private let dotmatrixProduct = "com.flowfinders.devsweep.skin.dotmatrix"
    private let allAccessId = ProductCatalog.allAccessId

    @Test func loadPopulatesProductsFromBackend() async {
        let store = SkinStore(backend: MockPurchaseBackend())
        await store.load()
        #expect(store.products.map(\.id) == ProductCatalog.all.map(\.id))
    }

    @Test func nothingOwnedLeavesAllPaidSkinsLocked() async {
        let store = SkinStore(backend: MockPurchaseBackend())
        await store.load()
        #expect(store.unlockedSkinIds.isEmpty)
    }

    @Test func buyingASingleSkinUnlocksIt() async {
        let store = SkinStore(backend: MockPurchaseBackend())
        await store.load()
        let ok = await store.buy(dotmatrixProduct)
        #expect(ok)
        #expect(store.unlockedSkinIds.contains("dot-matrix"))
    }

    @Test func failedPurchaseLeavesSkinLocked() async {
        let store = SkinStore(backend: MockPurchaseBackend(purchaseSucceeds: false))
        await store.load()
        let ok = await store.buy(dotmatrixProduct)
        #expect(!ok)
        #expect(store.unlockedSkinIds.isEmpty)
    }

    @Test func buyingAllAccessUnlocksEverySkin() async {
        let store = SkinStore(backend: MockPurchaseBackend())
        await store.load()
        _ = await store.buy(allAccessId)
        #expect(store.unlockedSkinIds == ["dot-matrix", "synthwave"])
    }

    @Test func restoreReinstatesPreviouslyOwnedSkins() async {
        let backend = MockPurchaseBackend(restoreAdds: ["com.flowfinders.devsweep.skin.synthwave"])
        let store = SkinStore(backend: backend)
        await store.load()
        #expect(store.unlockedSkinIds.isEmpty)
        await store.restorePurchases()
        #expect(store.unlockedSkinIds.contains("synthwave"))
    }

    @Test func loadReflectsPreexistingEntitlements() async {
        let store = SkinStore(backend: MockPurchaseBackend(owned: [allAccessId]))
        await store.load()
        #expect(store.unlockedSkinIds == ["dot-matrix", "synthwave"])
    }

    @Test func freeSkinsAreAlwaysSelectable() async {
        let store = SkinStore(backend: MockPurchaseBackend())
        await store.load()
        for skin in SkinCatalog.free {
            #expect(store.canSelect(skin))
        }
    }

    @Test func paidSkinSelectableOnlyAfterUnlock() async {
        let store = SkinStore(backend: MockPurchaseBackend())
        await store.load()
        let dotMatrix = SkinCatalog.skin(id: "dot-matrix")!
        #expect(!store.canSelect(dotMatrix))
        _ = await store.buy(dotmatrixProduct)
        #expect(store.canSelect(dotMatrix))
    }

    @Test func purchaseInFlightResetsAfterBuy() async {
        let store = SkinStore(backend: MockPurchaseBackend())
        await store.load()
        _ = await store.buy(dotmatrixProduct)
        #expect(!store.purchaseInFlight)
    }

    @Test func refundRelocksAPreviouslyOwnedSkin() async {
        // The highest-risk M6 path: a refunded/revoked entitlement must re-lock its skin.
        let backend = MockPurchaseBackend(owned: [dotmatrixProduct])
        let store = SkinStore(backend: backend)
        await store.load()
        let dotMatrix = SkinCatalog.skin(id: "dot-matrix")!
        #expect(store.canSelect(dotMatrix))

        await backend.revoke(dotmatrixProduct) // App Store refund / revocation
        await store.refresh()
        #expect(!store.canSelect(dotMatrix))
        #expect(store.unlockedSkinIds.isEmpty)
    }

    @Test func concurrentBuyIsRejectedWhileOneIsInFlight() async {
        // A double-tap (two buy buttons) must not run two purchases or flicker purchaseInFlight.
        let backend = MockPurchaseBackend(holdPurchase: true)
        let store = SkinStore(backend: backend)
        await store.load()

        async let first = store.buy(dotmatrixProduct)
        await backend.waitUntilPurchaseStarted()
        #expect(store.purchaseInFlight)

        let second = await store.buy("com.flowfinders.devsweep.skin.synthwave")
        #expect(second == false) // rejected by the in-flight guard, never reaches the backend

        await backend.releasePurchase()
        let firstResult = await first
        #expect(firstResult == true)

        let calls = await backend.purchaseCalls
        #expect(calls == [dotmatrixProduct])
    }
}
