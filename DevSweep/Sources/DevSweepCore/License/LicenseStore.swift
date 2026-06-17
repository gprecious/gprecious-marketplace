import Combine
import Foundation

/// The menu's license view-model. Activates/validates a key via an injected `LicenseActivating`,
/// persists via `LicenseStorage`, republishes the tier. `@MainActor ObservableObject`; no
/// networking/Keychain here (real impls injected by the app), mirroring the SkinStore/PurchaseBackend
/// split. Server rejection re-locks immediately; only transport failures use the offline grace.
@MainActor
public final class LicenseStore: ObservableObject {
    @Published public private(set) var entitlement: LicenseEntitlement = .free
    @Published public private(set) var unlockedSkinIds: Set<String> = []
    @Published public private(set) var activationState: ActivationState = .idle

    private let client: any LicenseActivating
    private let storage: any LicenseStorage
    private let binding: LicenseBinding
    private let config: LicenseConfig
    private let deviceName: String
    private let now: @Sendable () -> Date

    public init(client: any LicenseActivating, storage: any LicenseStorage, config: LicenseConfig,
                deviceName: String, now: @escaping @Sendable () -> Date = { Date() }) {
        self.client = client; self.storage = storage; self.binding = LicenseBinding(config: config)
        self.config = config; self.deviceName = deviceName; self.now = now
    }

    public var isPro: Bool { entitlement == .pro }
    public var checkoutURL: URL { config.checkoutURL }
    public var displayPrice: String { config.displayPrice }

    /// True when the last successful validation is older than `maxAge` (or never). Drives the
    /// menu-open re-validation (rev #6).
    public func isStale(maxAge: TimeInterval) -> Bool {
        guard let last = storage.load()?.lastValidatedAt else { return true }
        return now().timeIntervalSince(last) > maxAge
    }

    /// Stable activation label: device name + a per-install UUID so rename/reinstall doesn't burn a
    /// seat (rev #7).
    private var instanceName: String { "\(deviceName) [\(storage.installID())]" }

    public func activate(key: String) async {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { activationState = .invalid(reason: "키를 입력하세요"); return }
        activationState = .activating
        do {
            let result = try await client.activate(key: trimmed, instanceName: instanceName)
            guard result.activated, let instanceId = result.instanceId else {
                activationState = .invalid(reason: result.status.serverMessage
                    ?? "라이선스 활성화에 실패했습니다 (좌석 한도 초과일 수 있습니다)")
                return
            }
            guard binding.entitlement(for: result.status, now: now()) == .pro else {
                activationState = .invalid(reason: "이 키는 DevSweep Pro 라이선스가 아닙니다")
                return
            }
            storage.save(StoredLicense(key: trimmed, instanceId: instanceId, lastValidatedAt: now()))
            apply(.pro); activationState = .idle
        } catch let e as LicenseClientError {
            activationState = .invalid(reason: Self.message(for: e))
        } catch {
            activationState = .invalid(reason: "네트워크 오류로 활성화하지 못했습니다")
        }
    }

    /// Re-validate the stored license. Server rejection (valid:false, NOT a throw) → re-lock now.
    /// Only a thrown transport/5xx/429 error applies the offline grace window. rev #2.
    public func validate() async {
        guard let stored = storage.load() else { apply(.free); return }
        activationState = .validating
        do {
            let status = try await client.validate(key: stored.key, instanceId: stored.instanceId)
            if binding.entitlement(for: status, now: now()) == .pro {
                storage.save(StoredLicense(key: stored.key, instanceId: stored.instanceId, lastValidatedAt: now()))
                apply(.pro)
            } else {
                storage.clear(); apply(.free)        // refunded/disabled/expired → forget it now
            }
            activationState = .idle
        } catch {
            // transport/5xx/429 only (per client contract): keep Pro within grace, else re-lock.
            if let last = stored.lastValidatedAt, now().timeIntervalSince(last) < config.graceWindow {
                apply(.pro)
            } else {
                apply(.free)
            }
            activationState = .idle
        }
    }

    public func deactivate() async {
        if let stored = storage.load() {
            try? await client.deactivate(key: stored.key, instanceId: stored.instanceId)
        }
        storage.clear(); apply(.free); activationState = .idle
    }

    public func canSelect(_ skin: any SkinModule) -> Bool { skin.isFree || unlockedSkinIds.contains(skin.id) }

    private func apply(_ tier: LicenseEntitlement) {
        entitlement = tier
        unlockedSkinIds = (tier == .pro) ? Set(SkinCatalog.all.map(\.id)) : []
    }

    private static func message(for e: LicenseClientError) -> String {
        switch e {
        case .transport: return "네트워크 오류로 활성화하지 못했습니다"
        case .rateLimited: return "요청이 많습니다. 잠시 후 다시 시도해 주세요"
        case .server(let code): return "스토어 서버 오류(\(code)). 잠시 후 다시 시도해 주세요"
        }
    }
}
