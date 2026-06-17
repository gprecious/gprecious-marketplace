/// Persistence for the activated license + a stable install id (Keychain in production). Synchronous
/// (Keychain is sync; `LicenseStore` is `@MainActor`). The stored value is a credential — the
/// production conformer MUST use the Keychain, never UserDefaults.
public protocol LicenseStorage: Sendable {
    func load() -> StoredLicense?
    func save(_ license: StoredLicense)
    func clear()
    /// A stable, per-install random id used to build the activation `instance_name` (rev #7) so a
    /// rename/reinstall doesn't burn a seat. Created on first read and persisted.
    func installID() -> String
}
