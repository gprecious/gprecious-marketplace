import Foundation

/// Pure rule: a `LicenseStatus` grants Pro only when valid, active, unexpired, and from our
/// store + product. The single source of truth for entitlement.
public struct LicenseBinding: Sendable {
    private let config: LicenseConfig
    public init(config: LicenseConfig) { self.config = config }

    public func entitlement(for status: LicenseStatus, now: Date) -> LicenseEntitlement {
        guard status.valid, status.status == "active",
              status.storeId == config.expectedStoreId,
              let productId = status.productId, config.expectedProductIds.contains(productId)
        else { return .free }
        if let expiry = status.expiresAt, expiry <= now { return .free }
        return .pro
    }
}
