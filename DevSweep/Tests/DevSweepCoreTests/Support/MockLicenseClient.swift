import Foundation
@testable import DevSweepCore

/// Test double for `LicenseActivating`. `actor` for concurrency safety across `@MainActor`
/// `LicenseStore`. `throwError` simulates a transport/5xx/429 failure (grace path); a `validateStatus`
/// with valid=false simulates a server rejection (immediate re-lock path).
actor MockLicenseClient: LicenseActivating {
    var activateResult: ActivationResult
    var validateStatus: LicenseStatus
    var throwError: LicenseClientError?

    private(set) var activateCalls: [String] = []
    private(set) var validateCalls: [String] = []
    private(set) var deactivateCalls: [String] = []

    init(activateResult: ActivationResult, validateStatus: LicenseStatus, throwError: LicenseClientError? = nil) {
        self.activateResult = activateResult; self.validateStatus = validateStatus; self.throwError = throwError
    }
    func activate(key: String, instanceName: String) async throws -> ActivationResult {
        activateCalls.append(key); if let e = throwError { throw e }; return activateResult
    }
    func validate(key: String, instanceId: String) async throws -> LicenseStatus {
        validateCalls.append(key); if let e = throwError { throw e }; return validateStatus
    }
    func deactivate(key: String, instanceId: String) async throws { deactivateCalls.append(key) }

    func setThrowError(_ e: LicenseClientError?) { throwError = e }
    func setValidateStatus(_ s: LicenseStatus) { validateStatus = s }
}
