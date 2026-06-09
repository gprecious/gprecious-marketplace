import Testing
@testable import DevSweepCore

/// The IAP catalog is the offline source of truth for product ids, kinds, and recommended prices.
/// Tests pin the wire-format ids (App Store Connect must match exactly), the kind taxonomy, and the
/// invariant that every single-skin product references a real paid skin in `SkinCatalog`.
@Suite struct ProductCatalogTests {
    @Test func catalogIsNonEmpty() {
        #expect(!ProductCatalog.all.isEmpty)
    }

    @Test func everyProductIdIsBundlePrefixedAndUnique() {
        let ids = ProductCatalog.all.map(\.id)
        for id in ids {
            #expect(id.hasPrefix("kr.qplace.devsweep."))
        }
        #expect(Set(ids).count == ids.count) // no duplicates
    }

    @Test func everyProductHasDisplayNameAndPrice() {
        for product in ProductCatalog.all {
            #expect(!product.displayName.isEmpty)
            #expect(!product.displayPrice.isEmpty)
        }
    }

    @Test func allAccessProductExistsWithItsId() {
        let allAccess = ProductCatalog.product(id: ProductCatalog.allAccessId)
        #expect(allAccess != nil)
        #expect(allAccess?.kind == .allAccess)
    }

    @Test func singleSkinProductsReferenceRealPaidSkins() {
        let paidSkinIds = Set(SkinCatalog.paid.map(\.id))
        for product in ProductCatalog.all {
            if case .singleSkin(let skinId) = product.kind {
                #expect(paidSkinIds.contains(skinId), "single-skin product \(product.id) → unknown skin \(skinId)")
            }
        }
    }

    @Test func dotMatrixAndSynthwaveSoldAsSingles() {
        let dot = ProductCatalog.singleSkinProduct(skinId: "dot-matrix")
        let synth = ProductCatalog.singleSkinProduct(skinId: "synthwave")
        #expect(dot?.id == "kr.qplace.devsweep.skin.dotmatrix")
        #expect(synth?.id == "kr.qplace.devsweep.skin.synthwave")
    }

    @Test func themePackBundlesBothPaidSkins() {
        let pack = ProductCatalog.all.first { if case .themePack = $0.kind { return true }; return false }
        #expect(pack != nil)
        if case .themePack(let ids)? = pack?.kind {
            #expect(Set(ids) == ["dot-matrix", "synthwave"])
        }
    }

    @Test func recommendedPricesMatchSpecLineup() {
        #expect(ProductCatalog.singleSkinProduct(skinId: "dot-matrix")?.displayPrice == "$1.99")
        #expect(ProductCatalog.singleSkinProduct(skinId: "synthwave")?.displayPrice == "$2.99")
        #expect(ProductCatalog.product(id: ProductCatalog.allAccessId)?.displayPrice == "$9.99")
    }

    @Test func productLookupReturnsNilForUnknownId() {
        #expect(ProductCatalog.product(id: "kr.qplace.devsweep.nope") == nil)
    }
}
