import Combine

/// The menu's purchase view-model: loads products, drives buy/restore through an injected
/// `PurchaseBackend`, and republishes the unlocked-skin set via `EntitlementResolver`.
///
/// `@MainActor ObservableObject` so SwiftUI (`MenuView`) observes it directly. It lives in
/// `DevSweepCore` (not `DevSweepApp`) so its state machine is unit-tested with `MockPurchaseBackend`
/// — the real `StoreKit2Backend` is injected by the app, exactly mirroring the M1–M4
/// protocol/real/mock split. No StoreKit or AppKit import here.
@MainActor
public final class SkinStore: ObservableObject {
    /// Loaded products (localized prices when backed by StoreKit; empty until `load()`).
    @Published public private(set) var products: [IAPProduct] = []
    /// Skin ids currently unlocked by the user's purchases. Free skins are never listed here —
    /// they're gated by `SkinModule.isFree`, not by ownership.
    @Published public private(set) var unlockedSkinIds: Set<String> = []
    /// `true` while a `buy` is awaiting the backend, so the UI can disable purchase controls.
    @Published public private(set) var purchaseInFlight = false

    private let backend: any PurchaseBackend
    private let resolver: EntitlementResolver
    private let catalog: [IAPProduct]

    public init(backend: any PurchaseBackend, catalog: [IAPProduct] = ProductCatalog.all) {
        self.backend = backend
        self.catalog = catalog
        self.resolver = EntitlementResolver(catalog: catalog)
    }

    /// Load product metadata and reconcile entitlements. Safe to call repeatedly (e.g. on launch and
    /// after a transaction update). Store/network failures degrade to an empty product list rather
    /// than throwing — paid skins simply stay locked.
    public func load() async {
        products = (try? await backend.loadProducts(ids: catalog.map(\.id))) ?? []
        await refresh()
    }

    /// Re-read current entitlements and republish the unlocked set. Called after load/buy/restore and
    /// from the app's `Transaction.updates` listener (external/Ask-to-Buy purchases).
    public func refresh() async {
        let owned = await backend.currentEntitlementIds()
        unlockedSkinIds = resolver.unlockedSkinIds(ownedProductIds: owned)
    }

    /// Buy a product. Returns `true` only on a verified purchase (user-cancel/pending/error → false).
    /// On success the unlocked set is refreshed before returning. Reentrancy-guarded: a second buy
    /// started while one is in flight (a double-tap across buy buttons) is rejected, so two purchases
    /// can't race and `purchaseInFlight` can't flicker false mid-flight.
    @discardableResult
    public func buy(_ productId: String) async -> Bool {
        guard !purchaseInFlight else { return false }
        purchaseInFlight = true
        defer { purchaseInFlight = false }
        let succeeded = (try? await backend.purchase(id: productId)) ?? false
        if succeeded {
            await refresh()
        }
        return succeeded
    }

    /// Restore past purchases, then refresh the unlocked set.
    public func restorePurchases() async {
        try? await backend.restore()
        await refresh()
    }

    /// The selection gate: free skins are always selectable; paid skins only once unlocked.
    public func canSelect(_ skin: any SkinModule) -> Bool {
        skin.isFree || unlockedSkinIds.contains(skin.id)
    }
}
