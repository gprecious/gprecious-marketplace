import Testing
@testable import DevSweepCore

/// `EntitlementResolver` is the pure mapping from owned **product** ids to unlocked **skin** ids.
/// It encodes the All-Access rule (owning it unlocks every skin referenced anywhere in the catalog)
/// and bundle expansion (theme packs / seasonal drops unlock their listed skins).
@Suite struct EntitlementResolverTests {
    private let resolver = EntitlementResolver() // default = ProductCatalog.all

    @Test func nothingOwnedUnlocksNothing() {
        #expect(resolver.unlockedSkinIds(ownedProductIds: []).isEmpty)
    }

    @Test func singleSkinProductUnlocksThatSkin() {
        let unlocked = resolver.unlockedSkinIds(ownedProductIds: ["kr.qplace.devsweep.skin.dotmatrix"])
        #expect(unlocked == ["dot-matrix"])
    }

    @Test func otherSingleSkinProductUnlocksOnlyItsSkin() {
        let unlocked = resolver.unlockedSkinIds(ownedProductIds: ["kr.qplace.devsweep.skin.synthwave"])
        #expect(unlocked == ["synthwave"])
    }

    @Test func themePackUnlocksAllBundledSkins() {
        let unlocked = resolver.unlockedSkinIds(ownedProductIds: ["kr.qplace.devsweep.themepack.retro"])
        #expect(unlocked == ["dot-matrix", "synthwave"])
    }

    @Test func allAccessUnlocksEverySkinInCatalog() {
        let unlocked = resolver.unlockedSkinIds(ownedProductIds: [ProductCatalog.allAccessId])
        #expect(unlocked == ["dot-matrix", "synthwave"])
    }

    @Test func allAccessDominatesEvenWithNoOtherProducts() {
        // Owning only All-Access must unlock skins that are otherwise sold individually.
        let unlocked = resolver.unlockedSkinIds(ownedProductIds: [ProductCatalog.allAccessId])
        #expect(unlocked.contains("dot-matrix"))
        #expect(unlocked.contains("synthwave"))
    }

    @Test func unknownProductIdsAreIgnored() {
        let unlocked = resolver.unlockedSkinIds(ownedProductIds: ["kr.qplace.devsweep.bogus"])
        #expect(unlocked.isEmpty)
    }

    @Test func multipleSinglesUnionTheirSkins() {
        let unlocked = resolver.unlockedSkinIds(ownedProductIds: [
            "kr.qplace.devsweep.skin.dotmatrix",
            "kr.qplace.devsweep.skin.synthwave",
        ])
        #expect(unlocked == ["dot-matrix", "synthwave"])
    }

    @Test func seasonalProductUnlocksItsSkinsViaInjectedCatalog() {
        // A seasonal drop isn't shipped yet (out of scope), but the resolver must handle the kind.
        let seasonal = IAPProduct(
            id: "kr.qplace.devsweep.season.winter",
            displayName: "겨울 한정",
            displayPrice: "$2.99",
            kind: .seasonal(["frost", "aurora"])
        )
        let resolver = EntitlementResolver(catalog: [seasonal])
        let unlocked = resolver.unlockedSkinIds(ownedProductIds: ["kr.qplace.devsweep.season.winter"])
        #expect(unlocked == ["frost", "aurora"])
    }

    @Test func allAccessUnlocksSkinsReferencedOnlyByPacksOrSeasons() {
        // All-Access must include skins that exist in the catalog only inside a pack/season,
        // not just standalone singles.
        let pack = IAPProduct(id: "p.pack", displayName: "pack", displayPrice: "$1", kind: .themePack(["only-in-pack"]))
        let allAccess = IAPProduct(id: "p.all", displayName: "all", displayPrice: "$9", kind: .allAccess)
        let resolver = EntitlementResolver(catalog: [pack, allAccess])
        let unlocked = resolver.unlockedSkinIds(ownedProductIds: ["p.all"])
        #expect(unlocked == ["only-in-pack"])
    }
}
