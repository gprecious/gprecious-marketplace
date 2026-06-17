import Testing
import Foundation
@testable import DevSweepCore

/// `LicenseBinding` is the single place the "is this key Pro?" rule lives: Pro only when valid,
/// active, unexpired, and issued by *our* store + product. Everything else → free.
@Suite struct LicenseBindingTests {
    private let config = LicenseConfig(
        checkoutURL: URL(string: "https://example.com/checkout")!,
        apiBaseURL: URL(string: "https://api.lemonsqueezy.com/v1/licenses")!,
        expectedStoreId: 42, expectedProductIds: [7],
        graceWindow: 14 * 24 * 3600, seatLimit: 3, displayPrice: "$9.99"
    )
    private let now = Date(timeIntervalSince1970: 1_000_000)

    private func status(valid: Bool = true, status: String = "active", storeId: Int? = 42,
                        productId: Int? = 7, expiresAt: Date? = nil) -> LicenseStatus {
        LicenseStatus(valid: valid, status: status, storeId: storeId, productId: productId,
                      expiresAt: expiresAt, activationLimit: 3, activationUsage: 1, serverMessage: nil)
    }

    @Test func validActiveMatchingKeyIsPro() {
        #expect(LicenseBinding(config: config).entitlement(for: status(), now: now) == .pro)
    }
    @Test func invalidKeyIsFree() {
        #expect(LicenseBinding(config: config).entitlement(for: status(valid: false), now: now) == .free)
    }
    @Test func refundedDisabledKeyIsFree() {
        #expect(LicenseBinding(config: config).entitlement(for: status(status: "disabled"), now: now) == .free)
    }
    @Test func wrongStoreIsFree() {
        #expect(LicenseBinding(config: config).entitlement(for: status(storeId: 99), now: now) == .free)
    }
    @Test func wrongProductIsFree() {
        #expect(LicenseBinding(config: config).entitlement(for: status(productId: 999), now: now) == .free)
    }
    @Test func expiredKeyIsFree() {
        #expect(LicenseBinding(config: config).entitlement(for: status(expiresAt: now.addingTimeInterval(-1)), now: now) == .free)
    }
    @Test func futureExpiryStillPro() {
        #expect(LicenseBinding(config: config).entitlement(for: status(expiresAt: now.addingTimeInterval(3600)), now: now) == .pro)
    }
}
