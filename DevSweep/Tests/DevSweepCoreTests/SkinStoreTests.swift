import Testing
@testable import DevSweepCore

/// `SkinStore` is the `@MainActor` state machine the menu observes: it loads products, drives
/// buy/restore through an injected `PurchaseBackend`, and republishes the unlocked-skin set via
/// `EntitlementResolver`. Driven entirely by `MockPurchaseBackend` so the logic is verified without
/// StoreKit. `canSelect` is the selection gate (free always; paid only when unlocked).
@Suite @MainActor struct SkinStoreTests {
    private let dotmatrixProduct = "kr.qplace.devsweep.skin.dotmatrix"
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
        let backend = MockPurchaseBackend(restoreAdds: ["kr.qplace.devsweep.skin.synthwave"])
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
}
