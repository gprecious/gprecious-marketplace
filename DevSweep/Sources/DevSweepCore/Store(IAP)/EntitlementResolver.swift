/// Pure mapping from owned **product** ids → unlocked **skin** ids. The single place the All-Access
/// rule lives: owning All-Access unlocks every skin referenced anywhere in the catalog (standalone,
/// in a pack, or in a season), so a future skin auto-unlocks for existing All-Access owners.
public struct EntitlementResolver: Sendable {
    private let catalog: [IAPProduct]

    public init(catalog: [IAPProduct] = ProductCatalog.all) {
        self.catalog = catalog
    }

    /// - Parameter ownedProductIds: product ids the user owns (from `currentEntitlementIds()`).
    /// - Returns: the set of skin ids those purchases unlock. All-Access short-circuits to "all skins".
    public func unlockedSkinIds(ownedProductIds: Set<String>) -> Set<String> {
        let owned = catalog.filter { ownedProductIds.contains($0.id) }

        let hasAllAccess = owned.contains { if case .allAccess = $0.kind { return true }; return false }
        if hasAllAccess {
            return Self.everySkinId(in: catalog)
        }

        var result: Set<String> = []
        for product in owned {
            result.formUnion(Self.skinIds(of: product.kind))
        }
        return result
    }

    /// Skin ids a single product kind grants. All-Access grants nothing here (handled at the catalog
    /// level by `everySkinId`) so it never short-circuits per-product expansion.
    private static func skinIds(of kind: IAPProduct.Kind) -> Set<String> {
        switch kind {
        case .singleSkin(let id): return [id]
        case .themePack(let ids), .seasonal(let ids): return Set(ids)
        case .allAccess: return []
        }
    }

    /// Union of every skin id referenced anywhere in the catalog — the All-Access entitlement.
    private static func everySkinId(in catalog: [IAPProduct]) -> Set<String> {
        catalog.reduce(into: Set<String>()) { $0.formUnion(skinIds(of: $1.kind)) }
    }
}
