import Foundation

/// Public (non-secret) config for the LemonSqueezy license path. store/product ids + checkout URL
/// are all public — the License API needs no API key — so shipping them in the binary is safe.
public struct LicenseConfig: Sendable, Equatable {
    public var checkoutURL: URL
    public var apiBaseURL: URL                 // https://api.lemonsqueezy.com/v1/licenses
    public var expectedStoreId: Int
    public var expectedProductIds: Set<Int>
    public var graceWindow: TimeInterval       // offline Pro survival after last good validation
    public var seatLimit: Int                  // mirrors product activation_limit (display)
    public var displayPrice: String            // menu pitch only (checkout shows authoritative price)

    public init(checkoutURL: URL, apiBaseURL: URL, expectedStoreId: Int,
                expectedProductIds: Set<Int>, graceWindow: TimeInterval, seatLimit: Int, displayPrice: String) {
        self.checkoutURL = checkoutURL; self.apiBaseURL = apiBaseURL
        self.expectedStoreId = expectedStoreId; self.expectedProductIds = expectedProductIds
        self.graceWindow = graceWindow; self.seatLimit = seatLimit; self.displayPrice = displayPrice
    }

    /// FIXME(release): replace store/product ids + checkoutURL with real LemonSqueezy values
    /// (docs/LICENSING.md). `isPlaceholder` gates release builds (Task 10) so a dead Pro can't ship.
    public static let production = LicenseConfig(
        checkoutURL: URL(string: "https://devsweep.lemonsqueezy.com/buy/REPLACE_ME")!,
        apiBaseURL: URL(string: "https://api.lemonsqueezy.com/v1/licenses")!,
        expectedStoreId: 0, expectedProductIds: [0],
        graceWindow: 14 * 24 * 3600, seatLimit: 3, displayPrice: "$9.99"
    )

    /// True while shipping placeholders — release builds must refuse this (rev #11).
    public var isPlaceholder: Bool {
        expectedStoreId == 0 || expectedProductIds.contains(0) || checkoutURL.absoluteString.contains("REPLACE_ME")
    }
}
