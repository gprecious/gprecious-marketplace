import Foundation
import Security
import DevSweepCore

/// `LicenseStorage` backed by the Keychain. The key is a credential (never UserDefaults). Stores a
/// JSON `StoredLicense` and a stable per-install UUID as two generic-password items. Update-first
/// upsert with OSStatus checks (a failed add after a blind delete would otherwise silently lose the
/// license); `...ThisDeviceOnly` so the credential isn't migrated off this Mac.
struct KeychainLicenseStorage: LicenseStorage {
    private let service = "com.flow-finders.devsweep.license"
    private let licenseAccount = "pro"
    private let installAccount = "install-id"

    func load() -> StoredLicense? {
        guard let data = read(account: licenseAccount),
              let stored = try? JSONDecoder().decode(StoredLicense.self, from: data) else { return nil }
        return stored
    }
    func save(_ license: StoredLicense) {
        guard let data = try? JSONEncoder().encode(license) else { return }
        write(account: licenseAccount, data: data)
    }
    func clear() { SecItemDelete(query(account: licenseAccount) as CFDictionary) }

    func installID() -> String {
        if let data = read(account: installAccount), let id = String(data: data, encoding: .utf8), !id.isEmpty {
            return id
        }
        let id = UUID().uuidString
        write(account: installAccount, data: Data(id.utf8))
        return id
    }

    // MARK: - Keychain primitives (update-first upsert, OSStatus-checked)
    private func query(account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service, kSecAttrAccount as String: account]
    }
    private func read(account: String) -> Data? {
        var q = query(account: account)
        q[kSecReturnData as String] = true; q[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        return SecItemCopyMatching(q as CFDictionary, &item) == errSecSuccess ? item as? Data : nil
    }
    private func write(account: String, data: Data) {
        let attrs: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query(account: account) as CFDictionary, attrs as CFDictionary)
        if status == errSecItemNotFound {
            var add = query(account: account)
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(add as CFDictionary, nil)
            assert(addStatus == errSecSuccess, "Keychain add failed: \(addStatus)")
        } else {
            assert(status == errSecSuccess, "Keychain update failed: \(status)")
        }
    }
}
