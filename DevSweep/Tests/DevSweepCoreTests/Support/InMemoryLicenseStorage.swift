import Foundation
@testable import DevSweepCore

/// In-memory `LicenseStorage` for tests. `@unchecked Sendable` with a lock (mirrors `AtomicDate`).
final class InMemoryLicenseStorage: LicenseStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: StoredLicense?
    private var install: String

    init(seed: StoredLicense? = nil, installID: String = "test-install-uuid") {
        self.stored = seed; self.install = installID
    }
    func load() -> StoredLicense? { lock.lock(); defer { lock.unlock() }; return stored }
    func save(_ license: StoredLicense) { lock.lock(); defer { lock.unlock() }; stored = license }
    func clear() { lock.lock(); defer { lock.unlock() }; stored = nil }
    func installID() -> String { lock.lock(); defer { lock.unlock() }; return install }
}
