import Foundation

/// Decodes LemonSqueezy License API responses into our pure models. In `DevSweepCore` (no
/// networking) so wire→model mapping is fixture-tested. Absent fields (invalid key → null
/// license_key/meta) degrade to a non-Pro status; the `error` string is retained for UX.
public enum LemonSqueezyDecoder {
    private struct KeyDTO: Decodable { let status: String?; let activation_limit: Int?; let activation_usage: Int?; let expires_at: String? }
    private struct InstanceDTO: Decodable { let id: String }
    private struct MetaDTO: Decodable { let store_id: Int?; let product_id: Int? }
    private struct ValidateDTO: Decodable { let valid: Bool; let error: String?; let license_key: KeyDTO?; let meta: MetaDTO? }
    private struct ActivateDTO: Decodable { let activated: Bool; let error: String?; let license_key: KeyDTO?; let instance: InstanceDTO?; let meta: MetaDTO? }

    public static func validation(from data: Data) throws -> LicenseStatus {
        let dto = try JSONDecoder().decode(ValidateDTO.self, from: data)
        return status(valid: dto.valid, error: dto.error, key: dto.license_key, meta: dto.meta)
    }
    public static func activation(from data: Data) throws -> ActivationResult {
        let dto = try JSONDecoder().decode(ActivateDTO.self, from: data)
        let st = status(valid: dto.activated, error: dto.error, key: dto.license_key, meta: dto.meta)
        return ActivationResult(activated: dto.activated, instanceId: dto.instance?.id, status: st)
    }

    private static func status(valid: Bool, error: String?, key: KeyDTO?, meta: MetaDTO?) -> LicenseStatus {
        LicenseStatus(valid: valid, status: key?.status ?? "inactive",
                      storeId: meta?.store_id, productId: meta?.product_id,
                      expiresAt: key?.expires_at.flatMap(parseDate),
                      activationLimit: key?.activation_limit, activationUsage: key?.activation_usage,
                      serverMessage: error)
    }

    /// LemonSqueezy emits ISO8601 with up to 6 fractional digits (microseconds) + Z. `ISO8601DateFormatter`
    /// only handles 3, so use explicit `DateFormatter` formats with a plain-second fallback (rev #3).
    private static func parseDate(_ s: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone(identifier: "UTC")
        for fmt in ["yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX", "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX", "yyyy-MM-dd'T'HH:mm:ssXXXXX"] {
            f.dateFormat = fmt
            if let d = f.date(from: s) { return d }
        }
        return nil
    }
}
