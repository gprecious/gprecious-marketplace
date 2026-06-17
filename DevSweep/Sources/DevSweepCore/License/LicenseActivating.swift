/// Distinguishes a "the server reached us and rejected the key" outcome (returned as a
/// LicenseStatus with valid=false → re-lock now) from a "we couldn't get an answer" outcome
/// (thrown → caller applies offline grace). rev #2/#10.
public enum LicenseClientError: Error, Sendable, Equatable {
    case transport          // URLError / no connectivity
    case rateLimited        // HTTP 429
    case server(Int)        // 5xx (or unexpected non-JSON 4xx)
}

/// Abstraction over the LemonSqueezy License API. Real `LemonSqueezyLicenseClient` lives in the app;
/// `LicenseStore` is unit-tested with `MockLicenseClient`. `Sendable` to cross actor boundaries.
///
/// Contract (rev #2): activate/validate THROW only `LicenseClientError` (transport/5xx/429). A key
/// the server rejects (invalid/disabled/404/422) is NOT a throw — it returns a `LicenseStatus` with
/// `valid == false` so the caller re-locks immediately instead of entering offline grace.
public protocol LicenseActivating: Sendable {
    func activate(key: String, instanceName: String) async throws -> ActivationResult
    func validate(key: String, instanceId: String) async throws -> LicenseStatus
    func deactivate(key: String, instanceId: String) async throws
}
