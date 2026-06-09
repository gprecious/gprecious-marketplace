import StoreKit
import DevSweepCore

/// The production `PurchaseBackend` — StoreKit 2 (`Product` / `Transaction` / `AppStore`). Stateless
/// (`struct` → `Sendable`); all purchase logic that can be unit-tested lives in `SkinStore`
/// (`DevSweepCore`, driven by `MockPurchaseBackend`). This file is **compile-verified**: real
/// purchases require a signed Mac App Store build (or the bundled `DevSweep.storekit` in Xcode).
///
/// On-device verification only (`VerificationResult`): no receipt server is needed for non-consumable
/// IAPs — StoreKit 2 cryptographically verifies each transaction (`Guideline`-compliant).
struct StoreKit2Backend: PurchaseBackend {
    func loadProducts(ids: [String]) async throws -> [IAPProduct] {
        let storeProducts = try await Product.products(for: ids)
        return storeProducts.compactMap(Self.mapped)
    }

    func purchase(id: String) async throws -> Bool {
        let storeProducts = try await Product.products(for: [id])
        guard let product = storeProducts.first else { return false }

        switch try await product.purchase() {
        case .success(let verification):
            let transaction = try Self.checkVerified(verification)
            await transaction.finish() // never leave a verified transaction unfinished
            return true
        case .userCancelled, .pending:
            return false
        @unknown default:
            return false
        }
    }

    func currentEntitlementIds() async -> Set<String> {
        var ids: Set<String> = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            // Skip refunded / revoked entitlements — a refunded skin must re-lock.
            if transaction.revocationDate == nil {
                ids.insert(transaction.productID)
            }
        }
        return ids
    }

    func restore() async throws {
        // Re-syncs the App Store account; `currentEntitlements` reflects restored purchases after.
        try await AppStore.sync()
    }

    /// Map a StoreKit product onto our pure model: `kind` comes from the offline catalog (StoreKit
    /// doesn't know skin ids), the price string comes localized from StoreKit. Products absent from
    /// the catalog are dropped.
    private static func mapped(_ product: Product) -> IAPProduct? {
        guard let template = ProductCatalog.product(id: product.id) else { return nil }
        return IAPProduct(
            id: product.id,
            displayName: product.displayName,
            displayPrice: product.displayPrice,
            kind: template.kind
        )
    }

    private static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error): throw error
        case .verified(let safe): return safe
        }
    }
}

extension StoreKit2Backend {
    /// Observe transactions completed outside an explicit `buy` — Ask-to-Buy approvals, family
    /// sharing, or purchases made on another device. Each verified transaction is finished and
    /// `onChange` is invoked so `SkinStore` re-reads entitlements. Returns the long-lived task; the
    /// caller cancels it on teardown.
    func observeTransactionUpdates(onChange: @escaping @Sendable () async -> Void) -> Task<Void, Never> {
        Task.detached {
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else { continue }
                await transaction.finish()
                await onChange()
            }
        }
    }
}
