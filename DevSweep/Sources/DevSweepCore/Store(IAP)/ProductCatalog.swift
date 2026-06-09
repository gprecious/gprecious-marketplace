import Foundation

/// A single in-app purchase product. Pure value type (no StoreKit dependency) so the catalog,
/// entitlement resolution, and the purchase state machine are all testable in `DevSweepCore`.
///
/// `displayPrice` is the **recommended USD price** in the offline catalog (used for App Store Connect
/// setup and as a pre-load fallback); at runtime `StoreKit2Backend` rebuilds each product with the
/// **localized** `Product.displayPrice`. `kind` maps a product to the skin id(s) it unlocks.
public struct IAPProduct: Sendable, Equatable {
    /// App Store Connect product identifier, e.g. `kr.qplace.devsweep.skin.dotmatrix`.
    public let id: String
    /// Human-facing product name shown in the menu.
    public let displayName: String
    /// Localized price string at runtime; recommended USD price (`"$1.99"`) in the offline catalog.
    public let displayPrice: String
    /// What the product unlocks.
    public let kind: Kind

    /// The unlock taxonomy. `seasonal` mirrors `themePack` semantically but is tagged separately so
    /// future season drops can be filtered/labelled; the resolver treats both as "these skin ids".
    public enum Kind: Sendable, Equatable {
        /// Unlocks exactly one skin id.
        case singleSkin(String)
        /// Unlocks a bundle of skin ids at a pack price.
        case themePack([String])
        /// Unlocks every skin in the catalog (current and future).
        case allAccess
        /// A time-limited drop; permanently owned once bought. Unlocks the listed skin ids.
        case seasonal([String])
    }

    public init(id: String, displayName: String, displayPrice: String, kind: Kind) {
        self.id = id
        self.displayName = displayName
        self.displayPrice = displayPrice
        self.kind = kind
    }
}

/// The offline IAP catalog — the source of truth for product ids, kinds, and recommended prices.
/// App Store Connect products MUST be created with these exact ids (the `--list-products` output and
/// the bundled `DevSweep.storekit` config both derive from this). Lineup mirrors design spec §6(A):
/// paid single skins ($1.99 / $2.99), a retro theme pack ($3.99), and an anchoring All-Access ($9.99).
public enum ProductCatalog {
    /// All-Access product id — owning it unlocks every skin in the catalog.
    public static let allAccessId = "kr.qplace.devsweep.allaccess"

    /// Every IAP product, in menu display order.
    public static let all: [IAPProduct] = [
        IAPProduct(
            id: "kr.qplace.devsweep.skin.dotmatrix",
            displayName: "도트 매트릭스",
            displayPrice: "$1.99",
            kind: .singleSkin("dot-matrix")
        ),
        IAPProduct(
            id: "kr.qplace.devsweep.skin.synthwave",
            displayName: "신스웨이브",
            displayPrice: "$2.99",
            kind: .singleSkin("synthwave")
        ),
        IAPProduct(
            id: "kr.qplace.devsweep.themepack.retro",
            displayName: "레트로 테마팩",
            displayPrice: "$3.99",
            kind: .themePack(["dot-matrix", "synthwave"])
        ),
        IAPProduct(
            id: allAccessId,
            displayName: "올 액세스",
            displayPrice: "$9.99",
            kind: .allAccess
        ),
    ]

    /// Look up a product by id, or `nil` if unknown.
    public static func product(id: String) -> IAPProduct? {
        all.first { $0.id == id }
    }

    /// The single-skin product that unlocks `skinId`, if one is sold standalone (drives "Buy $X").
    public static func singleSkinProduct(skinId: String) -> IAPProduct? {
        all.first { if case .singleSkin(let id) = $0.kind { return id == skinId }; return false }
    }
}
