# DevSweep LemonSqueezy 라이선스 수익화 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** DevSweep(Developer ID 메뉴바 앱)에 LemonSqueezy 라이선스 키 기반 "DevSweep Pro" 평생 라이선스를 붙여 실제 수익화한다.

**Architecture:** StoreKit 의존 없는 순수 License 서브시스템(`Core/License/`)을 신설한다 — `LicenseActivating` 프로토콜, 순수 `LicenseBinding`(validate 응답 → `.pro`/`.free`), `@MainActor LicenseStore` 상태머신, keyless LemonSqueezy License API를 직접 호출하는 App 레이어 클라이언트 + Keychain 저장. 무료/Pro 게이팅은 순수 `ReclaimGate`/`AutoReclaimPolicy`로 분리해 단위 테스트한다. 기존 StoreKit 코드는 삭제하지 않고 동면시킨다.

**Tech Stack:** Swift 6 / SwiftPM, Swift Testing(`import Testing`, `@Suite`/`@Test`/`#expect`), SwiftUI(메뉴 팝오버), URLSession, Security(Keychain). macOS 14+.

---

## 배경 (필독)

- 결제 메커니즘·제공자·가격·무료/Pro 경계는 확정됨. spec 참조:
  `docs/superpowers/specs/2026-06-17-devsweep-license-monetization-design.md`.
- LemonSqueezy License API(`/v1/licenses/activate|validate|deactivate`)는 **API 키 불필요** —
  라이선스 키 자체가 인증 파라미터다. 앱이 직접 호출하며 별도 서버가 없다.
- `validate`/`activate` 응답의 `meta.store_id`/`meta.product_id`로 "내 Pro 상품 키"임을 바인딩 검증,
  `license_key.status`/최상위 `valid`로 환불 시 자동 재잠금.
- **Pro는 이진(binary)** 이다. 따라서 스킨 unlock은 `entitlement == .pro ? 전 스킨 : 없음`으로 단순
  계산한다(다중상품용 `EntitlementResolver`는 동면 StoreKit 경로 전용으로 남는다 — spec의 "재사용"
  표현보다 이 이진 방식이 단순/명확하여 채택).

## 프로젝트 규약 (지킬 것)

- 테스트 프레임워크: **Swift Testing**. `import Testing` + `@Suite`/`@Test`/`#expect`. XCTest 금지.
- 테스트 더블은 `Tests/DevSweepCoreTests/Support/`에 둔다(기존 `MockPurchaseBackend.swift` 패턴).
- `now: @Sendable () -> Date` 주입 패턴(예: `ScanCoordinator`, `ReclaimRouter`)을 시각 의존 로직에 사용.
- 빌드: `swift build`. 전체 테스트: `swift test`. 단일: `swift test --filter <SuiteName>`.
- 작업 브랜치: `feat/devsweep-license-monetization` (이미 체크아웃됨, spec 커밋 있음).
- 커밋 메시지 말미: `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`

## 파일 구조 (생성/수정)

**생성 (Core, 순수·테스트 대상):**
- `Sources/DevSweepCore/License/LicenseModels.swift` — `LicenseStatus`, `ActivationResult`, `LicenseEntitlement`, `ActivationState`, `StoredLicense`
- `Sources/DevSweepCore/License/LicenseConfig.swift` — 체크아웃 URL, API base, expected store/product id, grace window, 좌석수
- `Sources/DevSweepCore/License/LicenseBinding.swift` — 순수: `LicenseStatus` → `.pro`/`.free`
- `Sources/DevSweepCore/License/LicenseActivating.swift` — 프로토콜
- `Sources/DevSweepCore/License/LicenseStorage.swift` — 프로토콜
- `Sources/DevSweepCore/License/LicenseStore.swift` — `@MainActor ObservableObject` 상태머신
- `Sources/DevSweepCore/License/LemonSqueezyDecoding.swift` — 순수 JSON 디코딩 → 모델
- `Sources/DevSweepCore/License/ReclaimGate.swift` — 순수 게이팅 결정
- `Sources/DevSweepCore/License/AutoReclaimPolicy.swift` — 순수 자동청소 결정

**생성 (App, 실제 구현·컴파일 검증):**
- `Sources/DevSweepApp/License/LemonSqueezyLicenseClient.swift` — URLSession form-POST
- `Sources/DevSweepApp/License/KeychainLicenseStorage.swift` — Security 프레임워크

**생성 (테스트 더블):**
- `Tests/DevSweepCoreTests/Support/MockLicenseClient.swift`
- `Tests/DevSweepCoreTests/Support/InMemoryLicenseStorage.swift`

**생성 (테스트):**
- `Tests/DevSweepCoreTests/LicenseBindingTests.swift`
- `Tests/DevSweepCoreTests/LicenseStoreTests.swift`
- `Tests/DevSweepCoreTests/LemonSqueezyDecodingTests.swift`
- `Tests/DevSweepCoreTests/ReclaimGateTests.swift`
- `Tests/DevSweepCoreTests/AutoReclaimPolicyTests.swift`

**수정:**
- `Sources/DevSweepApp/AppCoordinator.swift` — StoreKit 주입 → LicenseStore, validate-on-start, 게이트된 reclaim, 자동청소
- `Sources/DevSweepApp/MenuView.swift` — 라이선스/Pro UI, 모듈별 회수, 게이트 라벨, 푸터
- `Sources/DevSweepApp/StatusItemController.swift` — `MenuView` 생성 시 `licenseStore` 주입(2곳)
- `packaging/RELEASE.md` — 수익화 경로 갱신
- 신규 `docs/LICENSING.md` — LemonSqueezy 대시보드 셋업 절차

---

## Task 1: License 모델 + Config + Binding (Core, 순수)

**Files:**
- Create: `Sources/DevSweepCore/License/LicenseModels.swift`
- Create: `Sources/DevSweepCore/License/LicenseConfig.swift`
- Create: `Sources/DevSweepCore/License/LicenseBinding.swift`
- Test: `Tests/DevSweepCoreTests/LicenseBindingTests.swift`

- [ ] **Step 1: Write the failing test**

`Tests/DevSweepCoreTests/LicenseBindingTests.swift`:
```swift
import Testing
import Foundation
@testable import DevSweepCore

/// `LicenseBinding` is the single place the "is this key Pro?" rule lives: a key unlocks Pro only
/// when it is valid, active, NOT expired, and issued by *our* store + product. Everything else
/// (refunded, disabled, expired, a key from someone else's LemonSqueezy product) resolves to free.
@Suite struct LicenseBindingTests {
    private let config = LicenseConfig(
        checkoutURL: URL(string: "https://example.com/checkout")!,
        apiBaseURL: URL(string: "https://api.lemonsqueezy.com/v1/licenses")!,
        expectedStoreId: 42,
        expectedProductIds: [7],
        graceWindow: 14 * 24 * 3600,
        seatLimit: 3
    )
    private let now = Date(timeIntervalSince1970: 1_000_000)

    private func status(
        valid: Bool = true, status: String = "active", storeId: Int? = 42,
        productId: Int? = 7, expiresAt: Date? = nil
    ) -> LicenseStatus {
        LicenseStatus(valid: valid, status: status, storeId: storeId, productId: productId,
                      expiresAt: expiresAt, activationLimit: 3, activationUsage: 1)
    }

    @Test func validActiveMatchingKeyIsPro() {
        let binding = LicenseBinding(config: config)
        #expect(binding.entitlement(for: status(), now: now) == .pro)
    }

    @Test func invalidKeyIsFree() {
        let binding = LicenseBinding(config: config)
        #expect(binding.entitlement(for: status(valid: false), now: now) == .free)
    }

    @Test func refundedDisabledKeyIsFree() {
        let binding = LicenseBinding(config: config)
        #expect(binding.entitlement(for: status(status: "disabled"), now: now) == .free)
    }

    @Test func wrongStoreIsFree() {
        let binding = LicenseBinding(config: config)
        #expect(binding.entitlement(for: status(storeId: 99), now: now) == .free)
    }

    @Test func wrongProductIsFree() {
        let binding = LicenseBinding(config: config)
        #expect(binding.entitlement(for: status(productId: 999), now: now) == .free)
    }

    @Test func expiredKeyIsFree() {
        let binding = LicenseBinding(config: config)
        let past = now.addingTimeInterval(-1)
        #expect(binding.entitlement(for: status(expiresAt: past), now: now) == .free)
    }

    @Test func futureExpiryStillPro() {
        let binding = LicenseBinding(config: config)
        let future = now.addingTimeInterval(3600)
        #expect(binding.entitlement(for: status(expiresAt: future), now: now) == .pro)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter LicenseBindingTests`
Expected: FAIL — `cannot find 'LicenseConfig' / 'LicenseStatus' / 'LicenseBinding' in scope`.

- [ ] **Step 3: Write the models**

`Sources/DevSweepCore/License/LicenseModels.swift`:
```swift
import Foundation

/// A snapshot of a license key's server-side state, as returned by activate/validate. Pure value
/// type (no networking/StoreKit) so the binding + store logic is unit-tested without a backend.
public struct LicenseStatus: Sendable, Equatable {
    /// Top-level `valid` flag from the License API response.
    public let valid: Bool
    /// `license_key.status` — "active" | "inactive" | "expired" | "disabled".
    public let status: String
    /// `meta.store_id` — used to bind the key to our store.
    public let storeId: Int?
    /// `meta.product_id` — used to bind the key to the DevSweep Pro product.
    public let productId: Int?
    /// `license_key.expires_at`, parsed; nil for a lifetime (non-expiring) license.
    public let expiresAt: Date?
    /// Seat (device) limit + current usage, for UI/diagnostics.
    public let activationLimit: Int?
    public let activationUsage: Int?

    public init(
        valid: Bool, status: String, storeId: Int?, productId: Int?,
        expiresAt: Date?, activationLimit: Int?, activationUsage: Int?
    ) {
        self.valid = valid
        self.status = status
        self.storeId = storeId
        self.productId = productId
        self.expiresAt = expiresAt
        self.activationLimit = activationLimit
        self.activationUsage = activationUsage
    }
}

/// Result of an `activate` call: whether activation succeeded, the issued instance id (needed for
/// later validate/deactivate), and the license status returned alongside it.
public struct ActivationResult: Sendable, Equatable {
    public let activated: Bool
    public let instanceId: String?
    public let status: LicenseStatus

    public init(activated: Bool, instanceId: String?, status: LicenseStatus) {
        self.activated = activated
        self.instanceId = instanceId
        self.status = status
    }
}

/// The unlocked tier. Binary: Pro unlocks every paid feature + every skin; free is the default.
public enum LicenseEntitlement: Sendable, Equatable { case free, pro }

/// UI-facing state of the activation flow, so the menu can show progress/errors.
public enum ActivationState: Sendable, Equatable {
    case idle
    case activating
    case validating
    /// A user-presentable reason the last activation/validation did not yield Pro.
    case invalid(reason: String)
}

/// What we persist locally (Keychain) once a key is activated: the key, its instance id, and the
/// timestamp of the last successful online validation (drives the offline grace window).
public struct StoredLicense: Sendable, Equatable, Codable {
    public let key: String
    public let instanceId: String
    public let lastValidatedAt: Date?

    public init(key: String, instanceId: String, lastValidatedAt: Date?) {
        self.key = key
        self.instanceId = instanceId
        self.lastValidatedAt = lastValidatedAt
    }
}
```

- [ ] **Step 4: Write the config**

`Sources/DevSweepCore/License/LicenseConfig.swift`:
```swift
import Foundation

/// Public (non-secret) configuration for the LemonSqueezy license path. store/product ids and the
/// checkout URL are all public values safe to ship in the binary — the License API needs no API key.
public struct LicenseConfig: Sendable, Equatable {
    /// Where "Buy DevSweep Pro" sends the user (opened in the default browser).
    public var checkoutURL: URL
    /// Base for `/activate`, `/validate`, `/deactivate` — `https://api.lemonsqueezy.com/v1/licenses`.
    public var apiBaseURL: URL
    /// Our LemonSqueezy store id; a key whose `meta.store_id` differs is rejected.
    public var expectedStoreId: Int
    /// The DevSweep Pro product id(s); a key for any other product is rejected.
    public var expectedProductIds: Set<Int>
    /// How long Pro survives offline after the last successful validation.
    public var graceWindow: TimeInterval
    /// Seat (device) limit, mirrored from the product's activation_limit (display only).
    public var seatLimit: Int

    public init(
        checkoutURL: URL, apiBaseURL: URL, expectedStoreId: Int,
        expectedProductIds: Set<Int>, graceWindow: TimeInterval, seatLimit: Int
    ) {
        self.checkoutURL = checkoutURL
        self.apiBaseURL = apiBaseURL
        self.expectedStoreId = expectedStoreId
        self.expectedProductIds = expectedProductIds
        self.graceWindow = graceWindow
        self.seatLimit = seatLimit
    }

    /// Production config. FIXME(release): replace the 0 placeholders + checkout URL with the real
    /// values from the LemonSqueezy dashboard (see docs/LICENSING.md). While ids are 0 no real key
    /// binds (every key's store/product differs), so Pro simply can't be activated — a safe default.
    public static let production = LicenseConfig(
        checkoutURL: URL(string: "https://devsweep.lemonsqueezy.com/buy/REPLACE_ME")!,
        apiBaseURL: URL(string: "https://api.lemonsqueezy.com/v1/licenses")!,
        expectedStoreId: 0,
        expectedProductIds: [0],
        graceWindow: 14 * 24 * 3600,
        seatLimit: 3
    )
}
```

- [ ] **Step 5: Write the binding**

`Sources/DevSweepCore/License/LicenseBinding.swift`:
```swift
import Foundation

/// Pure rule: a `LicenseStatus` grants Pro only when it is valid, active, unexpired, and issued by
/// our store + product. The single source of truth for entitlement — every other layer asks here.
public struct LicenseBinding: Sendable {
    private let config: LicenseConfig

    public init(config: LicenseConfig) { self.config = config }

    public func entitlement(for status: LicenseStatus, now: Date) -> LicenseEntitlement {
        guard status.valid,
              status.status == "active",
              status.storeId == config.expectedStoreId,
              let productId = status.productId,
              config.expectedProductIds.contains(productId)
        else { return .free }

        if let expiry = status.expiresAt, expiry <= now { return .free }
        return .pro
    }
}
```

- [ ] **Step 6: Run test to verify it passes**

Run: `swift test --filter LicenseBindingTests`
Expected: PASS (7 tests).

- [ ] **Step 7: Commit**

```bash
git add Sources/DevSweepCore/License/LicenseModels.swift \
        Sources/DevSweepCore/License/LicenseConfig.swift \
        Sources/DevSweepCore/License/LicenseBinding.swift \
        Tests/DevSweepCoreTests/LicenseBindingTests.swift
git commit -m "feat(devsweep): License models + config + binding (Pro entitlement rule)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: LicenseActivating + LicenseStorage 프로토콜 + 테스트 더블

**Files:**
- Create: `Sources/DevSweepCore/License/LicenseActivating.swift`
- Create: `Sources/DevSweepCore/License/LicenseStorage.swift`
- Create: `Tests/DevSweepCoreTests/Support/MockLicenseClient.swift`
- Create: `Tests/DevSweepCoreTests/Support/InMemoryLicenseStorage.swift`

- [ ] **Step 1: Write the protocols**

`Sources/DevSweepCore/License/LicenseActivating.swift`:
```swift
/// Abstraction over the LemonSqueezy License API — mirrors the `PurchaseBackend` pattern so
/// `LicenseStore` is driven by a protocol and unit-tested with `MockLicenseClient`, while the real
/// `LemonSqueezyLicenseClient` lives in `DevSweepApp`. `Sendable` to cross actor boundaries.
public protocol LicenseActivating: Sendable {
    /// Activate `key` for this device. `instanceName` is a human label (the Mac's name). Throws only
    /// on genuine network/store errors; a rejected/over-limit key returns `activated == false`.
    func activate(key: String, instanceName: String) async throws -> ActivationResult
    /// Re-check `key`+`instanceId`. Throws on network error (caller applies the offline grace).
    func validate(key: String, instanceId: String) async throws -> LicenseStatus
    /// Release this device's seat. Best-effort; throws on network error.
    func deactivate(key: String, instanceId: String) async throws
}
```

`Sources/DevSweepCore/License/LicenseStorage.swift`:
```swift
/// Persistence for the activated license (Keychain in production). Synchronous — the real backend is
/// the Keychain, which is synchronous; `LicenseStore` (`@MainActor`) calls it directly. The stored
/// value is a credential, so the production conformer MUST use the Keychain, never UserDefaults.
public protocol LicenseStorage: Sendable {
    func load() -> StoredLicense?
    func save(_ license: StoredLicense)
    func clear()
}
```

- [ ] **Step 2: Write the test doubles**

`Tests/DevSweepCoreTests/Support/MockLicenseClient.swift`:
```swift
import Foundation
@testable import DevSweepCore

/// Test double for `LicenseActivating`. An `actor` for concurrency safety across the `@MainActor`
/// `LicenseStore` boundary. Configure outcomes via init; `throwOnValidate`/`throwOnActivate`
/// simulate a network outage (so the store's offline-grace branch can be exercised).
actor MockLicenseClient: LicenseActivating {
    var activateResult: ActivationResult
    var validateStatus: LicenseStatus
    var throwOnActivate: Bool
    var throwOnValidate: Bool

    private(set) var activateCalls: [String] = []
    private(set) var validateCalls: [String] = []
    private(set) var deactivateCalls: [String] = []

    struct NetworkError: Error {}

    init(
        activateResult: ActivationResult,
        validateStatus: LicenseStatus,
        throwOnActivate: Bool = false,
        throwOnValidate: Bool = false
    ) {
        self.activateResult = activateResult
        self.validateStatus = validateStatus
        self.throwOnActivate = throwOnActivate
        self.throwOnValidate = throwOnValidate
    }

    func activate(key: String, instanceName: String) async throws -> ActivationResult {
        activateCalls.append(key)
        if throwOnActivate { throw NetworkError() }
        return activateResult
    }

    func validate(key: String, instanceId: String) async throws -> LicenseStatus {
        validateCalls.append(key)
        if throwOnValidate { throw NetworkError() }
        return validateStatus
    }

    func deactivate(key: String, instanceId: String) async throws {
        deactivateCalls.append(key)
    }

    // Test control: flip validate to a network outage mid-test.
    func setThrowOnValidate(_ v: Bool) { throwOnValidate = v }
    func setValidateStatus(_ s: LicenseStatus) { validateStatus = s }
}
```

`Tests/DevSweepCoreTests/Support/InMemoryLicenseStorage.swift`:
```swift
import Foundation
@testable import DevSweepCore

/// In-memory `LicenseStorage` for tests. `@unchecked Sendable` with a lock (mirrors `AtomicDate`),
/// since the protocol is synchronous + `Sendable` but `LicenseStore` only touches it on the main
/// actor in practice.
final class InMemoryLicenseStorage: LicenseStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: StoredLicense?

    init(seed: StoredLicense? = nil) { self.stored = seed }

    func load() -> StoredLicense? { lock.lock(); defer { lock.unlock() }; return stored }
    func save(_ license: StoredLicense) { lock.lock(); defer { lock.unlock() }; stored = license }
    func clear() { lock.lock(); defer { lock.unlock() }; stored = nil }
}
```

- [ ] **Step 3: Verify it compiles (no test yet — doubles are exercised in Task 3)**

Run: `swift build --build-tests`
Expected: builds with no errors.

- [ ] **Step 4: Commit**

```bash
git add Sources/DevSweepCore/License/LicenseActivating.swift \
        Sources/DevSweepCore/License/LicenseStorage.swift \
        Tests/DevSweepCoreTests/Support/MockLicenseClient.swift \
        Tests/DevSweepCoreTests/Support/InMemoryLicenseStorage.swift
git commit -m "feat(devsweep): LicenseActivating/LicenseStorage protocols + test doubles

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: LicenseStore 상태머신 (Core, `@MainActor`)

**Files:**
- Create: `Sources/DevSweepCore/License/LicenseStore.swift`
- Test: `Tests/DevSweepCoreTests/LicenseStoreTests.swift`

- [ ] **Step 1: Write the failing test**

`Tests/DevSweepCoreTests/LicenseStoreTests.swift`:
```swift
import Testing
import Foundation
@testable import DevSweepCore

/// `LicenseStore` is the `@MainActor` view-model the menu observes. It activates/validates through an
/// injected `LicenseActivating`, persists via `LicenseStorage`, and publishes `entitlement` +
/// `unlockedSkinIds`. Offline-grace keeps Pro alive within the window when validate hits a network
/// error; an explicit invalid response re-locks immediately. Driven by mocks (no network/Keychain).
@Suite @MainActor struct LicenseStoreTests {
    private let config = LicenseConfig(
        checkoutURL: URL(string: "https://example.com/buy")!,
        apiBaseURL: URL(string: "https://api.lemonsqueezy.com/v1/licenses")!,
        expectedStoreId: 42, expectedProductIds: [7],
        graceWindow: 14 * 24 * 3600, seatLimit: 3
    )
    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    private func proStatus() -> LicenseStatus {
        LicenseStatus(valid: true, status: "active", storeId: 42, productId: 7,
                      expiresAt: nil, activationLimit: 3, activationUsage: 1)
    }
    private func revokedStatus() -> LicenseStatus {
        LicenseStatus(valid: false, status: "disabled", storeId: 42, productId: 7,
                      expiresAt: nil, activationLimit: 3, activationUsage: 1)
    }
    private func makeStore(
        client: MockLicenseClient, storage: InMemoryLicenseStorage, now: Date
    ) -> LicenseStore {
        LicenseStore(client: client, storage: storage, config: config,
                     deviceName: "Test Mac", now: { now })
    }

    @Test func successfulActivationGrantsProAndUnlocksAllSkins() async {
        let client = MockLicenseClient(
            activateResult: ActivationResult(activated: true, instanceId: "inst-1", status: proStatus()),
            validateStatus: proStatus())
        let storage = InMemoryLicenseStorage()
        let store = makeStore(client: client, storage: storage, now: t0)

        await store.activate(key: "VALID-KEY")

        #expect(store.isPro)
        #expect(store.unlockedSkinIds == Set(SkinCatalog.all.map(\.id)))
        #expect(store.activationState == .idle)
        #expect(storage.load()?.instanceId == "inst-1")
    }

    @Test func activatingAKeyForAnotherProductIsRejected() async {
        let wrongProduct = LicenseStatus(valid: true, status: "active", storeId: 42, productId: 999,
                                         expiresAt: nil, activationLimit: 3, activationUsage: 1)
        let client = MockLicenseClient(
            activateResult: ActivationResult(activated: true, instanceId: "inst-1", status: wrongProduct),
            validateStatus: wrongProduct)
        let storage = InMemoryLicenseStorage()
        let store = makeStore(client: client, storage: storage, now: t0)

        await store.activate(key: "OTHER-PRODUCT-KEY")

        #expect(!store.isPro)
        #expect(storage.load() == nil)  // a non-Pro key is not persisted
        if case .invalid = store.activationState {} else { Issue.record("expected .invalid state") }
    }

    @Test func activationNetworkErrorSurfacesInvalidState() async {
        let client = MockLicenseClient(
            activateResult: ActivationResult(activated: false, instanceId: nil, status: revokedStatus()),
            validateStatus: revokedStatus(), throwOnActivate: true)
        let store = makeStore(client: client, storage: InMemoryLicenseStorage(), now: t0)

        await store.activate(key: "ANY")

        #expect(!store.isPro)
        if case .invalid = store.activationState {} else { Issue.record("expected .invalid state") }
    }

    @Test func validateRefundedKeyRelocksAndClearsStorage() async {
        let storage = InMemoryLicenseStorage(
            seed: StoredLicense(key: "K", instanceId: "inst-1", lastValidatedAt: t0))
        let client = MockLicenseClient(
            activateResult: ActivationResult(activated: true, instanceId: "inst-1", status: proStatus()),
            validateStatus: revokedStatus())
        let store = makeStore(client: client, storage: storage, now: t0)

        await store.validate()

        #expect(!store.isPro)
        #expect(storage.load() == nil)
    }

    @Test func validateWithinGraceWindowKeepsProOnNetworkError() async {
        let lastOK = t0
        let storage = InMemoryLicenseStorage(
            seed: StoredLicense(key: "K", instanceId: "inst-1", lastValidatedAt: lastOK))
        let client = MockLicenseClient(
            activateResult: ActivationResult(activated: true, instanceId: "inst-1", status: proStatus()),
            validateStatus: proStatus(), throwOnValidate: true)
        // 1 day later, still inside the 14-day grace window.
        let store = makeStore(client: client, storage: storage, now: lastOK.addingTimeInterval(24 * 3600))

        await store.validate()

        #expect(store.isPro)               // grace keeps Pro alive offline
        #expect(storage.load() != nil)     // license retained
    }

    @Test func validatePastGraceWindowRelocksOnNetworkError() async {
        let lastOK = t0
        let storage = InMemoryLicenseStorage(
            seed: StoredLicense(key: "K", instanceId: "inst-1", lastValidatedAt: lastOK))
        let client = MockLicenseClient(
            activateResult: ActivationResult(activated: true, instanceId: "inst-1", status: proStatus()),
            validateStatus: proStatus(), throwOnValidate: true)
        // 15 days later — past the 14-day grace window.
        let store = makeStore(client: client, storage: storage, now: lastOK.addingTimeInterval(15 * 24 * 3600))

        await store.validate()

        #expect(!store.isPro)
    }

    @Test func validateWithNoStoredLicenseIsFree() async {
        let client = MockLicenseClient(
            activateResult: ActivationResult(activated: true, instanceId: "inst-1", status: proStatus()),
            validateStatus: proStatus())
        let store = makeStore(client: client, storage: InMemoryLicenseStorage(), now: t0)

        await store.validate()

        #expect(!store.isPro)
        #expect(store.unlockedSkinIds.isEmpty)
    }

    @Test func deactivateReleasesSeatAndRelocks() async {
        let storage = InMemoryLicenseStorage(
            seed: StoredLicense(key: "K", instanceId: "inst-1", lastValidatedAt: t0))
        let client = MockLicenseClient(
            activateResult: ActivationResult(activated: true, instanceId: "inst-1", status: proStatus()),
            validateStatus: proStatus())
        let store = makeStore(client: client, storage: storage, now: t0)
        await store.validate()
        #expect(store.isPro)

        await store.deactivate()

        #expect(!store.isPro)
        #expect(storage.load() == nil)
        let calls = await client.deactivateCalls
        #expect(calls == ["K"])
    }

    @Test func canSelectGatesPaidSkinsButAllowsFreeSkins() async {
        let store = makeStore(client: MockLicenseClient(
            activateResult: ActivationResult(activated: true, instanceId: "i", status: proStatus()),
            validateStatus: proStatus()), storage: InMemoryLicenseStorage(), now: t0)
        // Free state: free skins selectable, paid not.
        let freeSkin = SkinCatalog.free.first!
        let paidSkin = SkinCatalog.paid.first!
        #expect(store.canSelect(freeSkin))
        #expect(!store.canSelect(paidSkin))

        await store.activate(key: "VALID")
        #expect(store.canSelect(paidSkin))  // Pro unlocks paid skins
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter LicenseStoreTests`
Expected: FAIL — `cannot find 'LicenseStore' in scope`.

- [ ] **Step 3: Write the LicenseStore**

`Sources/DevSweepCore/License/LicenseStore.swift`:
```swift
import Combine
import Foundation

/// The menu's license view-model: activates/validates a LemonSqueezy key through an injected
/// `LicenseActivating`, persists the result via `LicenseStorage`, and republishes the unlocked tier.
///
/// `@MainActor ObservableObject` so SwiftUI observes it directly; lives in `DevSweepCore` (the real
/// `LemonSqueezyLicenseClient`/`KeychainLicenseStorage` are injected by the app), mirroring the
/// protocol/real/mock split used by `SkinStore`/`PurchaseBackend`. No networking/Keychain here.
@MainActor
public final class LicenseStore: ObservableObject {
    /// Current tier. Drives feature gating across the app.
    @Published public private(set) var entitlement: LicenseEntitlement = .free
    /// Skin ids unlocked by the current tier — every skin when Pro, none when free (free skins are
    /// gated by `SkinModule.isFree`, not ownership). Computed from `entitlement`, never set directly.
    @Published public private(set) var unlockedSkinIds: Set<String> = []
    /// Activation-flow state for the menu (progress + error reason).
    @Published public private(set) var activationState: ActivationState = .idle

    private let client: any LicenseActivating
    private let storage: any LicenseStorage
    private let binding: LicenseBinding
    private let config: LicenseConfig
    private let deviceName: String
    private let now: @Sendable () -> Date

    public init(
        client: any LicenseActivating,
        storage: any LicenseStorage,
        config: LicenseConfig,
        deviceName: String,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.client = client
        self.storage = storage
        self.config = config
        self.binding = LicenseBinding(config: config)
        self.deviceName = deviceName
        self.now = now
    }

    public var isPro: Bool { entitlement == .pro }

    /// The checkout URL the menu opens for "Buy DevSweep Pro".
    public var checkoutURL: URL { config.checkoutURL }

    /// Activate a user-entered key: bind it, and on success persist {key, instanceId, now} and grant
    /// Pro. A key that activates but isn't *our* Pro product (or fails to activate) → `.invalid`.
    public func activate(key: String) async {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { activationState = .invalid(reason: "키를 입력하세요"); return }
        activationState = .activating
        do {
            let result = try await client.activate(key: trimmed, instanceName: deviceName)
            guard result.activated, let instanceId = result.instanceId else {
                activationState = .invalid(reason: "라이선스 활성화에 실패했습니다 (좌석 한도 초과일 수 있습니다)")
                return
            }
            let tier = binding.entitlement(for: result.status, now: now())
            guard tier == .pro else {
                activationState = .invalid(reason: "이 키는 DevSweep Pro 라이선스가 아닙니다")
                return
            }
            storage.save(StoredLicense(key: trimmed, instanceId: instanceId, lastValidatedAt: now()))
            apply(.pro)
            activationState = .idle
        } catch {
            activationState = .invalid(reason: "네트워크 오류로 활성화하지 못했습니다")
        }
    }

    /// Re-validate the stored license (call on launch + periodically). Applies the offline grace
    /// window on a network error; an explicit invalid/refunded response re-locks immediately.
    public func validate() async {
        guard let stored = storage.load() else { apply(.free); return }
        activationState = .validating
        do {
            let status = try await client.validate(key: stored.key, instanceId: stored.instanceId)
            let tier = binding.entitlement(for: status, now: now())
            if tier == .pro {
                storage.save(StoredLicense(key: stored.key, instanceId: stored.instanceId,
                                           lastValidatedAt: now()))
                apply(.pro)
            } else {
                storage.clear()      // refunded / disabled / expired → forget it
                apply(.free)
            }
            activationState = .idle
        } catch {
            // Network outage: keep Pro alive if still inside the grace window, else re-lock.
            if let last = stored.lastValidatedAt,
               now().timeIntervalSince(last) < config.graceWindow {
                apply(.pro)
            } else {
                apply(.free)
            }
            activationState = .idle
        }
    }

    /// Release this device's seat (best-effort) and re-lock locally.
    public func deactivate() async {
        if let stored = storage.load() {
            try? await client.deactivate(key: stored.key, instanceId: stored.instanceId)
        }
        storage.clear()
        apply(.free)
        activationState = .idle
    }

    /// Selection gate: free skins always; paid skins only when Pro.
    public func canSelect(_ skin: any SkinModule) -> Bool {
        skin.isFree || unlockedSkinIds.contains(skin.id)
    }

    private func apply(_ tier: LicenseEntitlement) {
        entitlement = tier
        unlockedSkinIds = (tier == .pro) ? Set(SkinCatalog.all.map(\.id)) : []
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter LicenseStoreTests`
Expected: PASS (9 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/DevSweepCore/License/LicenseStore.swift \
        Tests/DevSweepCoreTests/LicenseStoreTests.swift
git commit -m "feat(devsweep): LicenseStore state machine (activate/validate/deactivate + offline grace)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: LemonSqueezy JSON 디코딩 (Core, 순수)

**Files:**
- Create: `Sources/DevSweepCore/License/LemonSqueezyDecoding.swift`
- Test: `Tests/DevSweepCoreTests/LemonSqueezyDecodingTests.swift`

- [ ] **Step 1: Write the failing test**

`Tests/DevSweepCoreTests/LemonSqueezyDecodingTests.swift`:
```swift
import Testing
import Foundation
@testable import DevSweepCore

/// Decoding the LemonSqueezy License API JSON into our pure models. Fixtures mirror the documented
/// activate/validate response shapes so the App-layer URLSession client can stay a thin shell.
@Suite struct LemonSqueezyDecodingTests {
    private let validateJSON = """
    {
      "valid": true,
      "error": null,
      "license_key": {
        "id": 1, "status": "active", "key": "ABCD-1234",
        "activation_limit": 3, "activation_usage": 1, "expires_at": null
      },
      "instance": { "id": "inst-abc", "name": "Test Mac" },
      "meta": { "store_id": 42, "order_id": 5, "product_id": 7, "variant_id": 9 }
    }
    """.data(using: .utf8)!

    private let activateJSON = """
    {
      "activated": true,
      "error": null,
      "license_key": {
        "id": 1, "status": "active", "key": "ABCD-1234",
        "activation_limit": 3, "activation_usage": 2, "expires_at": "2030-01-02T03:04:05.000000Z"
      },
      "instance": { "id": "inst-xyz", "name": "Test Mac" },
      "meta": { "store_id": 42, "order_id": 5, "product_id": 7, "variant_id": 9 }
    }
    """.data(using: .utf8)!

    @Test func decodesValidateResponse() throws {
        let status = try LemonSqueezyDecoder.validation(from: validateJSON)
        #expect(status.valid)
        #expect(status.status == "active")
        #expect(status.storeId == 42)
        #expect(status.productId == 7)
        #expect(status.expiresAt == nil)
        #expect(status.activationLimit == 3)
    }

    @Test func decodesActivateResponseWithInstanceAndExpiry() throws {
        let result = try LemonSqueezyDecoder.activation(from: activateJSON)
        #expect(result.activated)
        #expect(result.instanceId == "inst-xyz")
        #expect(result.status.productId == 7)
        #expect(result.status.expiresAt != nil)   // ISO8601 with fractional seconds parsed
    }

    @Test func decodesInvalidValidateResponse() throws {
        let json = """
        { "valid": false, "error": "license_key not found", "license_key": null,
          "instance": null, "meta": null }
        """.data(using: .utf8)!
        let status = try LemonSqueezyDecoder.validation(from: json)
        #expect(!status.valid)
        #expect(status.status == "inactive")  // absent license_key → treated as inactive
        #expect(status.storeId == nil)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter LemonSqueezyDecodingTests`
Expected: FAIL — `cannot find 'LemonSqueezyDecoder' in scope`.

- [ ] **Step 3: Write the decoder**

`Sources/DevSweepCore/License/LemonSqueezyDecoding.swift`:
```swift
import Foundation

/// Decodes LemonSqueezy License API responses into our pure `LicenseStatus`/`ActivationResult`.
/// Kept in `DevSweepCore` (no networking) so the wire→model mapping is unit-tested with fixtures and
/// the App-layer `LemonSqueezyLicenseClient` is a thin URLSession shell. Absent fields (an invalid
/// key returns null `license_key`/`meta`) degrade to a clearly non-Pro status rather than throwing.
public enum LemonSqueezyDecoder {
    public func placeholder() {} // (no-op; enum kept as a namespace)

    private struct KeyDTO: Decodable {
        let status: String?
        let activation_limit: Int?
        let activation_usage: Int?
        let expires_at: String?
    }
    private struct InstanceDTO: Decodable { let id: String }
    private struct MetaDTO: Decodable { let store_id: Int?; let product_id: Int? }

    private struct ValidateDTO: Decodable {
        let valid: Bool
        let license_key: KeyDTO?
        let meta: MetaDTO?
    }
    private struct ActivateDTO: Decodable {
        let activated: Bool
        let license_key: KeyDTO?
        let instance: InstanceDTO?
        let meta: MetaDTO?
    }

    public static func validation(from data: Data) throws -> LicenseStatus {
        let dto = try JSONDecoder().decode(ValidateDTO.self, from: data)
        return status(valid: dto.valid, key: dto.license_key, meta: dto.meta)
    }

    public static func activation(from data: Data) throws -> ActivationResult {
        let dto = try JSONDecoder().decode(ActivateDTO.self, from: data)
        let status = status(valid: dto.activated, key: dto.license_key, meta: dto.meta)
        return ActivationResult(activated: dto.activated, instanceId: dto.instance?.id, status: status)
    }

    private static func status(valid: Bool, key: KeyDTO?, meta: MetaDTO?) -> LicenseStatus {
        LicenseStatus(
            valid: valid,
            status: key?.status ?? "inactive",
            storeId: meta?.store_id,
            productId: meta?.product_id,
            expiresAt: key?.expires_at.flatMap(parseDate),
            activationLimit: key?.activation_limit,
            activationUsage: key?.activation_usage
        )
    }

    /// LemonSqueezy timestamps are ISO8601 with fractional seconds + Z (e.g. 2030-01-02T03:04:05.000000Z).
    private static func parseDate(_ s: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = withFraction.date(from: s) { return d }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: s)
    }
}
```

> Note: delete the `placeholder()` line — it exists only to remind you `enum` is used as a namespace; it is not referenced. (Removing it keeps the file warning-free.)

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter LemonSqueezyDecodingTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/DevSweepCore/License/LemonSqueezyDecoding.swift \
        Tests/DevSweepCoreTests/LemonSqueezyDecodingTests.swift
git commit -m "feat(devsweep): LemonSqueezy License API response decoding (fixtures)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: LemonSqueezyLicenseClient (App, URLSession shell)

**Files:**
- Create: `Sources/DevSweepApp/License/LemonSqueezyLicenseClient.swift`

> No unit test: this is a thin networking shell (the testable mapping lives in `LemonSqueezyDecoder`).
> Compile-verified now; exercised live in Task 10's manual integration check.

- [ ] **Step 1: Write the client**

`Sources/DevSweepApp/License/LemonSqueezyLicenseClient.swift`:
```swift
import Foundation
import DevSweepCore

/// Production `LicenseActivating` — POSTs form-encoded requests to the keyless LemonSqueezy License
/// API and maps responses via `LemonSqueezyDecoder`. No API key (the license key itself authorizes).
/// `Sendable` struct; all decode/validation logic that can be unit-tested lives in `DevSweepCore`.
struct LemonSqueezyLicenseClient: LicenseActivating {
    let baseURL: URL          // https://api.lemonsqueezy.com/v1/licenses
    let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    enum ClientError: Error { case badStatus(Int) }

    func activate(key: String, instanceName: String) async throws -> ActivationResult {
        let data = try await post("activate", fields: ["license_key": key, "instance_name": instanceName])
        return try LemonSqueezyDecoder.activation(from: data)
    }

    func validate(key: String, instanceId: String) async throws -> LicenseStatus {
        let data = try await post("validate", fields: ["license_key": key, "instance_id": instanceId])
        return try LemonSqueezyDecoder.validation(from: data)
    }

    func deactivate(key: String, instanceId: String) async throws {
        _ = try await post("deactivate", fields: ["license_key": key, "instance_id": instanceId])
    }

    private func post(_ path: String, fields: [String: String]) async throws -> Data {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.formBody(fields)

        let (data, response) = try await session.data(for: request)
        // The License API returns 200 for valid/activated AND for "valid:false"/"activated:false"
        // (the body carries the verdict). 4xx/5xx are genuine transport/store errors → throw.
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode),
           http.statusCode != 400 {
            // 400 still carries a JSON body (e.g. "license_key not found") the decoder handles as invalid.
            throw ClientError.badStatus(http.statusCode)
        }
        return data
    }

    private static func formBody(_ fields: [String: String]) -> Data {
        let allowed = CharacterSet.urlQueryAllowed.subtracting(CharacterSet(charactersIn: "+&="))
        let encoded = fields.map { key, value in
            let k = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
            let v = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
            return "\(k)=\(v)"
        }.joined(separator: "&")
        return Data(encoded.utf8)
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `swift build`
Expected: builds (the App target compiles the new file).

- [ ] **Step 3: Commit**

```bash
git add Sources/DevSweepApp/License/LemonSqueezyLicenseClient.swift
git commit -m "feat(devsweep): LemonSqueezyLicenseClient (keyless License API URLSession shell)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: KeychainLicenseStorage (App)

**Files:**
- Create: `Sources/DevSweepApp/License/KeychainLicenseStorage.swift`

> No CI unit test (Keychain needs a real keychain/entitlements). The `LicenseStorage` contract is
> covered by `InMemoryLicenseStorage` in Task 3; this conformer is compile-verified + manually
> verified in Task 10.

- [ ] **Step 1: Write the Keychain storage**

`Sources/DevSweepApp/License/KeychainLicenseStorage.swift`:
```swift
import Foundation
import Security
import DevSweepCore

/// `LicenseStorage` backed by the macOS Keychain. The license key is a credential, so it must not
/// land in UserDefaults. Stores a single JSON-encoded `StoredLicense` as a generic password item
/// keyed by (service, account). `Sendable`: stateless struct; every call hits the Keychain directly.
struct KeychainLicenseStorage: LicenseStorage {
    private let service = "com.flow-finders.devsweep.license"
    private let account = "pro"

    func load() -> StoredLicense? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let stored = try? JSONDecoder().decode(StoredLicense.self, from: data)
        else { return nil }
        return stored
    }

    func save(_ license: StoredLicense) {
        guard let data = try? JSONEncoder().encode(license) else { return }
        SecItemDelete(baseQuery as CFDictionary)  // upsert: clear any existing item first
        var attributes = baseQuery
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(attributes as CFDictionary, nil)
    }

    func clear() {
        SecItemDelete(baseQuery as CFDictionary)
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `swift build`
Expected: builds.

- [ ] **Step 3: Commit**

```bash
git add Sources/DevSweepApp/License/KeychainLicenseStorage.swift
git commit -m "feat(devsweep): KeychainLicenseStorage (credential persisted in Keychain)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: ReclaimGate + AutoReclaimPolicy (Core, 순수)

**Files:**
- Create: `Sources/DevSweepCore/License/ReclaimGate.swift`
- Create: `Sources/DevSweepCore/License/AutoReclaimPolicy.swift`
- Test: `Tests/DevSweepCoreTests/ReclaimGateTests.swift`
- Test: `Tests/DevSweepCoreTests/AutoReclaimPolicyTests.swift`

- [ ] **Step 1: Write the failing tests**

`Tests/DevSweepCoreTests/ReclaimGateTests.swift`:
```swift
import Testing
@testable import DevSweepCore

/// `ReclaimGate` is the pure free/Pro rule for reclaim actions: dry-run preview is always free;
/// real one-click "reclaim all" and Docker prune are Pro; per-module reclaim of the safe modules
/// (node_modules, package caches, worktrees) is free.
@Suite struct ReclaimGateTests {
    private let gate = ReclaimGate()

    @Test func dryRunIsAlwaysAllowed() {
        #expect(gate.decide(scope: .all, isPro: false, dryRun: true) == .allow)
        #expect(gate.decide(scope: .module("docker"), isPro: false, dryRun: true) == .allow)
    }

    @Test func reclaimAllRequiresProWhenNotPro() {
        #expect(gate.decide(scope: .all, isPro: false, dryRun: false) == .requiresPro)
    }

    @Test func reclaimAllAllowedWhenPro() {
        #expect(gate.decide(scope: .all, isPro: true, dryRun: false) == .allow)
    }

    @Test func perModuleSafeModuleIsFree() {
        #expect(gate.decide(scope: .module("node-modules"), isPro: false, dryRun: false) == .allow)
        #expect(gate.decide(scope: .module("package-cache"), isPro: false, dryRun: false) == .allow)
        #expect(gate.decide(scope: .module("git-worktrees"), isPro: false, dryRun: false) == .allow)
    }

    @Test func perModuleDockerRequiresPro() {
        #expect(gate.decide(scope: .module("docker"), isPro: false, dryRun: false) == .requiresPro)
        #expect(gate.decide(scope: .module("docker"), isPro: true, dryRun: false) == .allow)
    }
}
```

`Tests/DevSweepCoreTests/AutoReclaimPolicyTests.swift`:
```swift
import Testing
@testable import DevSweepCore

/// Scheduled/automatic reclaim (hands-off cleaning) runs only when the user is Pro AND has opted in.
@Suite struct AutoReclaimPolicyTests {
    private let policy = AutoReclaimPolicy()

    @Test func autoReclaimOnlyWhenProAndEnabled() {
        #expect(policy.shouldAutoReclaim(isPro: true, autoCleanEnabled: true))
        #expect(!policy.shouldAutoReclaim(isPro: true, autoCleanEnabled: false))
        #expect(!policy.shouldAutoReclaim(isPro: false, autoCleanEnabled: true))
        #expect(!policy.shouldAutoReclaim(isPro: false, autoCleanEnabled: false))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter ReclaimGateTests`
Run: `swift test --filter AutoReclaimPolicyTests`
Expected: FAIL — `cannot find 'ReclaimGate' / 'AutoReclaimPolicy' in scope`.

- [ ] **Step 3: Write the gate**

`Sources/DevSweepCore/License/ReclaimGate.swift`:
```swift
/// Pure free/Pro decision for reclaim actions. Single source of the gating line:
/// - dry-run preview: always free (look without paying);
/// - real one-click "reclaim all": Pro;
/// - real per-module reclaim: free for the safe modules, Pro for Docker prune (high-risk/advanced).
public struct ReclaimGate: Sendable {
    /// Module ids that require Pro even for a single-module real reclaim.
    public static let proOnlyModuleIds: Set<String> = ["docker"]

    public enum Scope: Sendable, Equatable {
        /// One-click reclaim of every reviewed item across all modules.
        case all
        /// Reclaim a single module's items, identified by module id.
        case module(String)
    }

    public enum Decision: Sendable, Equatable { case allow, requiresPro }

    public init() {}

    public func decide(scope: Scope, isPro: Bool, dryRun: Bool) -> Decision {
        if dryRun { return .allow }
        if isPro { return .allow }
        switch scope {
        case .all:
            return .requiresPro
        case .module(let id):
            return Self.proOnlyModuleIds.contains(id) ? .requiresPro : .allow
        }
    }
}
```

`Sources/DevSweepCore/License/AutoReclaimPolicy.swift`:
```swift
/// Pure rule for scheduled/automatic reclaim: only when the user is Pro and has opted in via the
/// menu's auto-clean toggle. Keeps the decision testable + out of the `@MainActor` coordinator.
public struct AutoReclaimPolicy: Sendable {
    public init() {}

    public func shouldAutoReclaim(isPro: Bool, autoCleanEnabled: Bool) -> Bool {
        isPro && autoCleanEnabled
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter ReclaimGateTests`
Run: `swift test --filter AutoReclaimPolicyTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/DevSweepCore/License/ReclaimGate.swift \
        Sources/DevSweepCore/License/AutoReclaimPolicy.swift \
        Tests/DevSweepCoreTests/ReclaimGateTests.swift \
        Tests/DevSweepCoreTests/AutoReclaimPolicyTests.swift
git commit -m "feat(devsweep): ReclaimGate + AutoReclaimPolicy (free/Pro gating rules)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: AppCoordinator 배선 (StoreKit → License, 게이트된 reclaim, 자동청소)

**Files:**
- Modify: `Sources/DevSweepApp/AppCoordinator.swift`

This task rewires the coordinator from the dormant StoreKit `SkinStore` to the live `LicenseStore`,
adds Pro-gated reclaim entry points, and an opt-in auto-clean path. The `SkinSelectionReconciler`
(pure) is reused unchanged — it just reads `licenseStore.unlockedSkinIds` now.

- [ ] **Step 1: Replace the StoreKit properties with the LicenseStore**

In `Sources/DevSweepApp/AppCoordinator.swift`, replace the skin-store/backend declarations.

Replace (around lines 52-54):
```swift
    /// IAP state: loaded products, unlocked-skin set, buy/restore. The menu observes it directly; the
    /// coordinator consults it to gate skin selection. The real `StoreKit2Backend` is injected here.
    let skinStore: SkinStore
```
with:
```swift
    /// License state: tier, unlocked-skin set, activation flow. The menu observes it directly; the
    /// coordinator consults `isPro`/`canSelect` to gate skin selection and reclaim actions. The real
    /// `LemonSqueezyLicenseClient` + `KeychainLicenseStorage` are injected here.
    let licenseStore: LicenseStore
```

Replace (around lines 81-83):
```swift
    /// Production purchase backend — one stateless instance shared by `skinStore` and the
    /// `Transaction.updates` observer.
    private let purchaseBackend = StoreKit2Backend()
```
with:
```swift
    /// Pure free/Pro gating rules consulted by the reclaim entry points + the auto-clean path.
    private let reclaimGate = ReclaimGate()
    private let autoReclaimPolicy = AutoReclaimPolicy()

    /// UserDefaults key for the Pro-only "auto-clean on scan" opt-in toggle.
    private static let autoCleanKey = "DevSweep.autoCleanEnabled"
```

Remove the `transactionObserver` property (StoreKit-only; around lines 85-86):
```swift
    /// Long-lived `Transaction.updates` listener (Ask-to-Buy, family sharing, other devices).
    private var transactionObserver: Task<Void, Never>?
```
(delete those two lines).

- [ ] **Step 2: Rewire the initializer**

Replace (around line 134):
```swift
        self.skinStore = SkinStore(backend: purchaseBackend)
```
with:
```swift
        self.licenseStore = LicenseStore(
            client: LemonSqueezyLicenseClient(baseURL: LicenseConfig.production.apiBaseURL),
            storage: KeychainLicenseStorage(),
            config: .production,
            deviceName: Host.current().localizedName ?? "Mac"
        )
```

- [ ] **Step 3: Rewire `start()` — validate the license instead of loading StoreKit products**

Replace (around lines 184-193):
```swift
        Task { [weak self] in
            await self?.skinStore.load()
            self?.didLoadEntitlements = true
            self?.reconcileSkinSelection()
        }
        // React to transactions completed outside an explicit buy (Ask-to-Buy, family sharing, other
        // devices) so an external unlock/refund is reflected without a relaunch.
        transactionObserver = purchaseBackend.observeTransactionUpdates { [weak self] in
            await self?.handleEntitlementChange()
        }
```
with:
```swift
        // Validate the stored license (offline-grace aware), then reconcile the persisted skin
        // selection against what Pro unlocks (re-apply a persisted paid skin; revert if no longer Pro).
        Task { [weak self] in
            await self?.licenseStore.validate()
            self?.didLoadEntitlements = true
            self?.reconcileSkinSelection()
        }
```

- [ ] **Step 4: Update the skin-selection gate + reconciler reads**

Replace (around line 252):
```swift
              skinStore.canSelect(skin) else { return }
```
with:
```swift
              licenseStore.canSelect(skin) else { return }
```

Replace (around line 268):
```swift
            unlockedSkinIds: skinStore.unlockedSkinIds,
```
with:
```swift
            unlockedSkinIds: licenseStore.unlockedSkinIds,
```

Replace the now-StoreKit-specific `handleEntitlementChange()` (around lines 282-286):
```swift
    /// An external transaction changed ownership — refresh the unlocked set and reconcile selection.
    private func handleEntitlementChange() async {
        await skinStore.refresh()
        reconcileSkinSelection()
    }
```
with:
```swift
    /// Re-validate the license (e.g. after the user activates a key from the menu) and reconcile the
    /// skin selection against the new tier.
    func revalidateLicense() async {
        await licenseStore.validate()
        reconcileSkinSelection()
    }
```

- [ ] **Step 5: Add the Pro-gated reclaim entry points**

Add these methods to `AppCoordinator` (place them right after the existing `reclaim(approved:dryRun:)` method, around line 342). They wrap the existing reclaim path with `ReclaimGate`; a blocked action publishes `proGateHit` so the menu can prompt purchase.

First add a published signal near the other `@Published` properties (after line 41):
```swift
    /// Set to the blocked scope's label when a non-Pro user taps a Pro-only reclaim action, so the
    /// menu can surface a "DevSweep Pro" prompt. The menu clears it after presenting.
    @Published var proGateHit: String?
```

Then add the entry points:
```swift
    /// One-click "reclaim all reviewed items". Pro-gated for a real run; dry-run preview is free.
    /// A blocked real run sets `proGateHit` and returns no outcomes.
    @discardableResult
    func reclaimAll(dryRun: Bool) async -> [ReclaimOutcome] {
        guard gateAllows(scope: .all, dryRun: dryRun, label: "전체 회수") else { return [] }
        return await reclaim(approved: currentItems, dryRun: dryRun)
    }

    /// Reclaim a single module's reviewed items. Free for the safe modules; Docker prune is Pro.
    @discardableResult
    func reclaimModule(id moduleId: String, dryRun: Bool) async -> [ReclaimOutcome] {
        guard gateAllows(scope: .module(moduleId), dryRun: dryRun,
                         label: moduleNames[moduleId] ?? moduleId) else { return [] }
        let items = currentGrouped.first { $0.module == moduleId }?.items ?? []
        return await reclaim(approved: items, dryRun: dryRun)
    }

    /// Consult the gate; on `.requiresPro` publish the prompt + return false.
    private func gateAllows(scope: ReclaimGate.Scope, dryRun: Bool, label: String) -> Bool {
        switch reclaimGate.decide(scope: scope, isPro: licenseStore.isPro, dryRun: dryRun) {
        case .allow:
            return true
        case .requiresPro:
            proGateHit = label
            return false
        }
    }
```

- [ ] **Step 6: Add the opt-in auto-clean path (Pro)**

Add the toggle accessors + hook auto-reclaim into the post-scan flow.

Add accessors (near the other helpers, e.g. after `setSkin`):
```swift
    /// The Pro-only "auto-clean after scan" opt-in (persisted). Free users can read it but the
    /// auto-reclaim path also checks `licenseStore.isPro`, so a stale `true` never cleans for free.
    var autoCleanEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.autoCleanKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.autoCleanKey) }
    }
```

In `scanNow()`, after `apply(record: result.record)` settles the loop (i.e. right after the
`repeat { … } while rescanPending` block, before `isScanning = false`), add the auto-clean hook:
```swift
        } while rescanPending
        await autoCleanIfEnabled()
        isScanning = false
    }

    /// Pro + opt-in only: silently reclaim the safe (non-Docker) modules after a scan, then the
    /// scan inside `reclaim` refreshes the indicator. Docker stays manual even for Pro (high-risk).
    private func autoCleanIfEnabled() async {
        guard autoReclaimPolicy.shouldAutoReclaim(isPro: licenseStore.isPro,
                                                  autoCleanEnabled: autoCleanEnabled) else { return }
        let safeItems = currentGrouped
            .filter { !ReclaimGate.proOnlyModuleIds.contains($0.module) }
            .flatMap(\.items)
        guard !safeItems.isEmpty else { return }
        _ = await reclaim(approved: safeItems, dryRun: false)
    }
```

> Note: `reclaim(approved:dryRun:)` already re-scans after a real reclaim, and `scanNow` is
> reentrancy-guarded (`isReclaiming`/`rescanPending`), so the nested re-scan coalesces safely.

- [ ] **Step 7: Build + run the full suite**

Run: `swift build`
Expected: builds (StoreKit `SkinStore`/`StoreKit2Backend` remain in the tree, just no longer wired).

Run: `swift test`
Expected: all tests PASS — the new License suites plus the existing 205 (the dormant StoreKit
`SkinStoreTests`/`PurchaseBackendTests` still pass against `MockPurchaseBackend`).

- [ ] **Step 8: Commit**

```bash
git add Sources/DevSweepApp/AppCoordinator.swift
git commit -m "feat(devsweep): wire LicenseStore into AppCoordinator + Pro-gated reclaim/auto-clean

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 9: MenuView + StatusItemController UI (라이선스/Pro/모듈별 회수)

**Files:**
- Modify: `Sources/DevSweepApp/StatusItemController.swift` (2 `MenuView(...)` call sites)
- Modify: `Sources/DevSweepApp/MenuView.swift`

> UI work. Verified by build + manual launch (Task 10's UI HARD GATE), not unit tests.

- [ ] **Step 1: Swap the injected store in StatusItemController**

In `Sources/DevSweepApp/StatusItemController.swift`, both `MenuView(...)` constructions (around
lines 26-28 and 34-36) pass `skinStore: coordinator.skinStore`. Change both to:
```swift
                licenseStore: coordinator.licenseStore,
```

- [ ] **Step 2: Update MenuView's observed store + signature**

In `Sources/DevSweepApp/MenuView.swift`, replace:
```swift
    @ObservedObject var skinStore: SkinStore
```
with:
```swift
    @ObservedObject var licenseStore: LicenseStore
    @State private var licenseKeyInput = ""
    @State private var showingLicenseSheet = false
```

- [ ] **Step 3: Add the Pro/license section to the body**

In `body`, replace the skin section block:
```swift
            skinPicker
            Divider()
            footer
```
with:
```swift
            skinPicker
            Divider()
            proSection
            Divider()
            footer
```

- [ ] **Step 4: Replace the skin picker (remove StoreKit buy buttons → Pro lock)**

Replace the entire `skinPicker`, `skinRow`, `allAccessRow`, and `price(for:)` members with a
license-driven picker. Delete `allAccessRow` and `price(for:)` (StoreKit-only). New code:
```swift
    private var skinPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("스킨")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(SkinCatalog.all, id: \.id) { skin in
                skinRow(skin)
            }
        }
    }

    /// One skin row: live preview + name, then a selection radio (free / Pro-unlocked) or a lock
    /// glyph (paid + not Pro). Tapping a locked paid skin opens the Pro purchase sheet.
    @ViewBuilder private func skinRow(_ skin: any SkinModule) -> some View {
        let selectable = licenseStore.canSelect(skin)
        HStack(spacing: 8) {
            Image(nsImage: skin.image(for: previewState, height: 16))
                .frame(width: 44, alignment: .leading)
            Text(skin.displayName)
                .font(.callout)
                .foregroundStyle(selectable ? .primary : .secondary)
            Spacer()
            if selectable {
                Image(systemName: skin.id == coordinator.currentSkinId ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(skin.id == coordinator.currentSkinId ? Color.accentColor : Color.secondary)
            } else {
                Label("Pro", systemImage: "lock.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if selectable { coordinator.setSkin(id: skin.id) }
            else { showingLicenseSheet = true }
        }
    }
```

- [ ] **Step 5: Add the Pro section (status badge / buy / activate / deactivate)**

Add a new `proSection` member and the license-entry sheet:
```swift
    @ViewBuilder private var proSection: some View {
        if licenseStore.isPro {
            VStack(alignment: .leading, spacing: 6) {
                Label("DevSweep Pro 활성화됨", systemImage: "checkmark.seal.fill")
                    .font(.callout)
                    .foregroundStyle(.green)
                Toggle("스캔 후 자동 청소", isOn: Binding(
                    get: { coordinator.autoCleanEnabled },
                    set: { coordinator.autoCleanEnabled = $0 }
                ))
                .toggleStyle(.switch)
                .font(.callout)
                Button("이 기기에서 라이선스 해제") {
                    Task { await coordinator.licenseStore.deactivate() }
                }
                .font(.caption)
                .buttonStyle(.link)
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("DevSweep Pro")
                    .font(.callout)
                    .fontWeight(.semibold)
                Text("전체 회수 · 자동 청소 · Docker prune · 전 스킨")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Button("Pro 구매") {
                        NSWorkspace.shared.open(licenseStore.checkoutURL)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    Button("라이선스 키 입력") { showingLicenseSheet = true }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
        }
    }
```

Attach the sheet to the root `VStack` in `body` (add after `.frame(width: 300)`):
```swift
        .sheet(isPresented: $showingLicenseSheet) { licenseSheet }
```

Add the sheet view:
```swift
    private var licenseSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("라이선스 키 입력")
                .font(.headline)
            TextField("XXXX-XXXX-XXXX-XXXX", text: $licenseKeyInput)
                .textFieldStyle(.roundedBorder)
                .frame(width: 280)
            if case .invalid(let reason) = licenseStore.activationState {
                Label(reason, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Spacer()
                Button("취소") { showingLicenseSheet = false }
                Button("활성화") {
                    Task {
                        await licenseStore.activate(key: licenseKeyInput)
                        if licenseStore.isPro { showingLicenseSheet = false }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(licenseStore.activationState == .activating || licenseKeyInput.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 340)
    }
```

- [ ] **Step 6: Gate the reclaim actions (per-module free, "전체 회수" Pro)**

Replace the `actions` member's reclaim button block. The dry-run preview stays as one button (free);
add a Pro-gated "전체 회수" button and make module rows reclaimable. Replace the single reclaim
`Button { … } label: { Label(dryRun ? … ) }` (lines ~146-153) with:
```swift
            Button {
                let items = coordinator.currentItems
                Task { _ = await coordinator.reclaimAll(dryRun: true) } // preview is free
                _ = items
            } label: {
                Label("회수 미리보기", systemImage: "eye")
            }
            .disabled(actionPresentation.reclaimDisabled)

            Button {
                Task { _ = await coordinator.reclaimAll(dryRun: false) }
            } label: {
                Label(licenseStore.isPro ? "전체 회수 실행" : "전체 회수 (Pro)",
                      systemImage: licenseStore.isPro ? "trash" : "lock.fill")
            }
            .disabled(actionPresentation.reclaimDisabled)
```
Then remove the now-unused `dryRun` `@State` and its `Toggle` (lines ~10 and ~142-144) — preview vs
execute are now explicit buttons. (Delete `@State private var dryRun = true` and the
`Toggle("드라이런…")` block.)

Make the module rows in `moduleList` reclaimable (free per-module / Docker shows Pro lock). In the
`ForEach(coordinator.topModules)` row, wrap the content with a tap handler:
```swift
                ForEach(coordinator.topModules) { module in
                    HStack {
                        Text(module.name).font(.callout).lineLimit(1)
                        Spacer()
                        Text(humanBytes(module.bytes))
                            .font(.callout).monospacedDigit().foregroundStyle(.secondary)
                        if ReclaimGate.proOnlyModuleIds.contains(module.module) && !licenseStore.isPro {
                            Image(systemName: "lock.fill").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        Task { _ = await coordinator.reclaimModule(id: module.module, dryRun: false) }
                    }
                }
```

- [ ] **Step 7: Handle the Pro-gate prompt + update the footer**

Add a reaction to `coordinator.proGateHit` (open the license sheet when a Pro action is blocked).
Attach to the root `VStack` (after the `.sheet` modifier):
```swift
        .onChange(of: coordinator.proGateHit) { _, hit in
            if hit != nil {
                showingLicenseSheet = true
                coordinator.proGateHit = nil
            }
        }
```

Replace the footer's compliance line. Change:
```swift
            Text("모든 정리 기능은 계속 무료입니다.")
```
to:
```swift
            Text("핵심 정리는 무료 · Pro로 전체 회수·자동 청소·스킨")
```

- [ ] **Step 8: Build**

Run: `swift build`
Expected: builds with no errors (resolve any leftover references to the deleted `skinStore`,
`allAccessRow`, `price(for:)`, or `dryRun` — there should be none after the edits above).

- [ ] **Step 9: Commit**

```bash
git add Sources/DevSweepApp/MenuView.swift Sources/DevSweepApp/StatusItemController.swift
git commit -m "feat(devsweep): license/Pro menu UI — key entry, purchase, per-module reclaim, gating

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 10: 문서 + 통합/UI 검증 + dormant 표기

**Files:**
- Modify: `packaging/RELEASE.md`
- Create: `docs/LICENSING.md`

- [ ] **Step 1: Write the LemonSqueezy setup doc**

`docs/LICENSING.md`:
```markdown
# DevSweep Pro — LemonSqueezy 라이선스 셋업

DevSweep Pro 는 LemonSqueezy 라이선스 키로 잠금해제된다(StoreKit 아님 — Developer ID 배포라 사용 불가).
License API(`/v1/licenses/activate|validate|deactivate`)는 **API 키가 필요 없다** — 라이선스 키 자체가
인증 파라미터이므로 앱이 직접 호출하고, 별도 백엔드/영수증 서버가 없다.

## 대시보드에서 한 번 할 일 (자동화 불가)

1. LemonSqueezy 스토어 생성.
2. 상품 "DevSweep Pro" 생성:
   - 가격: 평생 1회 $19.99 (one-time).
   - **License keys 활성화**, `activation limit = 3` (기기 3대).
3. 다음 값을 확보해 `Sources/DevSweepCore/License/LicenseConfig.swift` 의 `.production` 에 기입:
   - `checkoutURL` — 상품 체크아웃(또는 buy) URL
   - `expectedStoreId` — 스토어 id (정수)
   - `expectedProductIds` — DevSweep Pro 의 product id (정수)
   - (이 값들은 전부 공개값 — 바이너리에 넣어도 안전)
4. 테스트 모드 라이선스 키를 발급해 아래 통합 검증을 수행.

## 검증 (테스트 모드 키)

- 앱 실행 → 메뉴 → "라이선스 키 입력" → 테스트 키 활성화 → "DevSweep Pro 활성화됨" 배지 확인.
- 환불/disable 시뮬레이션 후 재실행 → Pro 해제(free) 확인.
- "이 기기에서 라이선스 해제" → 좌석 반납 + free 복귀 확인.
- 네트워크 차단 후 재실행 → grace window(14일) 내 Pro 유지 확인.
```

- [ ] **Step 2: Update RELEASE.md monetization section**

In `packaging/RELEASE.md`, replace the "Consequence for StoreKit / In-App Purchases" section body
(the bullet list under that heading) with:
```markdown
StoreKit IAPs only work for App Store builds, so under Developer ID the active monetization path is a
**LemonSqueezy license key** (see `docs/LICENSING.md`):

- **DevSweep Pro** — a $19.99 lifetime license unlocks one-click "reclaim all", scheduled auto-clean,
  Docker prune, and every skin. Bought on an external LemonSqueezy checkout; activated in-app with the
  keyless License API (`LicenseStore` / `LemonSqueezyLicenseClient` / `KeychainLicenseStorage`).
- The free tier keeps the tool's core promise: manual scan, per-module reclaim (node_modules / package
  caches / worktrees), auto-scan, and the free skins.
- The **M6 StoreKit code** (`StoreKit2Backend`, the StoreKit-driven `SkinStore`, the IAP
  `ProductCatalog`, `DevSweep.storekit`) stays in the tree but is **dormant** — not wired into
  `AppCoordinator`. Kept for a possible future Mac App Store SKU; its unit tests still run.
- Donation links (`DonationLinks`) remain as a secondary, voluntary path.
```

- [ ] **Step 3: Run the full test suite**

Run: `swift test`
Expected: all PASS — License suites (Binding, Store, Decoding, ReclaimGate, AutoReclaimPolicy) +
the pre-existing 205.

- [ ] **Step 4: Build the app bundle + manual UI verification (HARD GATE)**

Run: `./packaging/build_app.sh --adhoc`
Then launch `build/DevSweep.app` and verify in the menubar popover:
- Free state: skins show "Pro" lock; "전체 회수 (Pro)" shows a lock; module rows reclaim individually;
  Docker row shows a lock.
- "라이선스 키 입력" opens the sheet; an empty/invalid key shows the red error; a valid test key flips
  to "DevSweep Pro 활성화됨" and unlocks skins + "전체 회수 실행" + the auto-clean toggle.
- "Pro 구매" opens the checkout URL in the browser.
- No crash; check Console for faults. (If a real test key isn't available yet because the dashboard
  isn't configured, verify the free-state gating + sheet open/close/validation messaging, and note the
  Pro-state path as "pending LemonSqueezy dashboard config".)

- [ ] **Step 5: Commit**

```bash
git add packaging/RELEASE.md docs/LICENSING.md
git commit -m "docs(devsweep): LemonSqueezy licensing setup + RELEASE monetization update

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## 완료 기준 (Definition of Done)

- [ ] `swift test` 전부 green (신규 License 스위트 + 기존 205).
- [ ] `swift build` + `./packaging/build_app.sh --adhoc` 성공, 메뉴 팝오버 수동 UI 검증 통과.
- [ ] 무료 상태: 모듈별 회수 동작, 전체 회수/Docker/스킨은 Pro 게이트.
- [ ] 라이선스 키 활성화 → Pro 전환 → 스킨/전체회수/자동청소 잠금해제 (테스트 키로 확인,
      또는 대시보드 미구성 시 free-state + 시트 검증까지).
- [ ] StoreKit 코드는 동면(트리 보존, 미배선), 기존 테스트 통과.
- [ ] `LicenseConfig.production` 의 store/product id·checkout URL 은 릴리스 전 실제 값으로 교체
      (FIXME 주석 + `docs/LICENSING.md`).
- [ ] push 는 사용자 승인 후에만.

## Self-Review 결과 (작성자 점검)

- **Spec 커버리지**: §2 아키텍처→Task 1-7, §3 게이팅→Task 7-9, §5 UX→Task 9, §6 사용자작업→Task 10,
  §7 테스트→각 Task TDD + Task 10 통합. 모든 spec 섹션이 태스크로 매핑됨.
- **Placeholder**: 모든 코드 스텝에 실제 코드 포함. `LicenseConfig.production` 의 0/REPLACE_ME 는
  의도된 릴리스-타임 값(FIXME + 문서화)으로, 미구현 placeholder 아님.
- **타입 일관성**: `LicenseStatus`/`ActivationResult`/`LicenseEntitlement`/`StoredLicense` 시그니처가
  Task 1 정의와 Task 3·4 사용처에서 일치. `ReclaimGate.proOnlyModuleIds` 가 Task 7 정의 →
  Task 8·9 사용 일관. `licenseStore`(프로퍼티명)·`canSelect`·`isPro`·`reclaimAll`/`reclaimModule`
  명칭이 Task 8·9 간 일치.
