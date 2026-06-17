import Foundation

/// Server-side state of a license key (from activate/validate). Pure value type — no networking.
public struct LicenseStatus: Sendable, Equatable {
    public let valid: Bool                 // top-level valid/activated flag
    public let status: String              // license_key.status: active|inactive|expired|disabled
    public let storeId: Int?               // meta.store_id
    public let productId: Int?             // meta.product_id
    public let expiresAt: Date?            // license_key.expires_at (nil = lifetime)
    public let activationLimit: Int?
    public let activationUsage: Int?
    public let serverMessage: String?      // LemonSqueezy `error` text, for UX (rev #10)

    public init(valid: Bool, status: String, storeId: Int?, productId: Int?, expiresAt: Date?,
                activationLimit: Int?, activationUsage: Int?, serverMessage: String?) {
        self.valid = valid; self.status = status; self.storeId = storeId; self.productId = productId
        self.expiresAt = expiresAt; self.activationLimit = activationLimit
        self.activationUsage = activationUsage; self.serverMessage = serverMessage
    }
}

/// Result of an `activate` call.
public struct ActivationResult: Sendable, Equatable {
    public let activated: Bool
    public let instanceId: String?
    public let status: LicenseStatus
    public init(activated: Bool, instanceId: String?, status: LicenseStatus) {
        self.activated = activated; self.instanceId = instanceId; self.status = status
    }
}

/// The unlocked tier. Binary: Pro unlocks every paid feature + every skin.
public enum LicenseEntitlement: Sendable, Equatable { case free, pro }

/// UI-facing activation-flow state, with a differentiated failure reason (rev #10).
public enum ActivationState: Sendable, Equatable {
    case idle, activating, validating
    case invalid(reason: String)
}

/// Persisted locally (Keychain): key, instance id, and last successful validation time (grace window).
public struct StoredLicense: Sendable, Equatable, Codable {
    public let key: String
    public let instanceId: String
    public let lastValidatedAt: Date?
    public init(key: String, instanceId: String, lastValidatedAt: Date?) {
        self.key = key; self.instanceId = instanceId; self.lastValidatedAt = lastValidatedAt
    }
}
