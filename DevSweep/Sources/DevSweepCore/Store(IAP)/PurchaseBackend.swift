/// Abstraction over the store backend — mirrors the M1–M4 pattern (`CommandRunner`,
/// `FileSystemDeleter`) so the purchase/restore/entitlement state machine (`SkinStore`) is driven by
/// a protocol and unit-tested with a mock, while the real `StoreKit2Backend` lives in `DevSweepApp`.
///
/// `Sendable` so backends can cross actor boundaries; `purchase` returns a Bool (a verified
/// transaction succeeded) rather than throwing on user-cancel — cancel/pending are `false`, not errors.
public protocol PurchaseBackend: Sendable {
    /// Load metadata for the given product ids (unknown ids are simply absent from the result).
    func loadProducts(ids: [String]) async throws -> [IAPProduct]
    /// Attempt to buy `id`. Returns `true` only on a verified, finished transaction; user-cancel /
    /// pending return `false`. Throws only on genuine store/network errors.
    func purchase(id: String) async throws -> Bool
    /// Product ids the user currently owns (StoreKit `Transaction.currentEntitlements`).
    func currentEntitlementIds() async -> Set<String>
    /// Restore past purchases (StoreKit `AppStore.sync()`); entitlements are re-read afterwards.
    func restore() async throws
}
