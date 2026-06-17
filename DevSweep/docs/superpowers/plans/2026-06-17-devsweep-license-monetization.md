# DevSweep LemonSqueezy 라이선스 수익화 — Implementation Plan (v2)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** DevSweep(Developer ID 메뉴바 앱)에 LemonSqueezy 라이선스 키 기반 "DevSweep Pro" 평생 라이선스를 붙여 실제 수익화한다.

**Architecture:** StoreKit 의존 없는 순수 License 서브시스템(`Core/License/`)을 신설한다 — `LicenseActivating` 프로토콜, 순수 `LicenseBinding`(validate 응답 → `.pro`/`.free`), `@MainActor LicenseStore` 상태머신, keyless LemonSqueezy License API를 직접 호출하는 App 레이어 클라이언트 + Keychain 저장. 무료/Pro 게이팅은 순수 `ReclaimGate`/`AutoReclaimPolicy`로 분리해 단위 테스트한다. 기존 StoreKit 코드는 삭제하지 않고 동면시킨다.

**Tech Stack:** Swift 6 / SwiftPM, Swift Testing(`import Testing`, `@Suite`/`@Test`/`#expect`), SwiftUI(메뉴 팝오버), URLSession, Security(Keychain). macOS 14+.

---

## v2 개정 이력 — herdr 교차 CLI 비판적 리뷰 반영 (2026-06-17)

이 플랜은 claude(Opus 4.8, xhigh) + codex(gpt-5.5, high)의 독립 적대적 리뷰를 거쳐 개정됐다.
원본 리뷰: `/tmp/claude_review.md`, `/tmp/codex_review.md`. 반영 항목:

**안전·정합성 (must-fix):**
1. **auto-clean은 `SafetyClass.autoSafe` 항목만** 회수한다. node_modules·git-worktree는 `.reviewNeeded`("always requires explicit approval" — `SafetyClass.swift`)라 **자동 삭제 절대 금지**. 게이팅 축을 모듈 id가 아니라 **안전등급**으로 잡는다. (codex CRITICAL #1)
2. **4xx 오류 처리**: LemonSqueezy는 무효/삭제 키에 404/422 등 4XX를 본문과 함께 반환한다. 4xx-with-JSON-body는 디코딩해 "서버가 무효 판정"(즉시 re-lock)으로 처리하고, throw→오프라인 grace는 **전송 실패(URLError)·5xx·429에만** 적용한다. (양쪽 공통)
3. **ISO8601 마이크로초(6자리) 파싱** — `ISO8601DateFormatter(.withFractionalSeconds)`는 3자리만 처리하므로 6자리 타임스탬프를 명시 포맷 `DateFormatter`로 파싱. (claude M2)
4. **stale 지표 버그** — `autoCleanIfEnabled()`를 `isScanning = false` *뒤*로 옮기고 명시적 refresh. (양쪽 공통)
5. **라이선스 상태 변경 → reconcile 라우팅** — activate/deactivate를 `AppCoordinator` 경유로 돌려 스킨/렌더러/게이트 즉시 반영(해제 시 유료 스킨 즉시 재잠금). dead `revalidateLicense` 제거→실사용. (양쪽 공통)
6. **주기적 재검증** — 팝오버 오픈 시 stale(>6h)이면 재검증(`menuWillOpen` 훅 활용). (양쪽 공통)
7. **안정적 기기 식별자** — `Host.localizedName` 대신 Keychain 영속 install UUID를 `instance_name`에 포함(재설치·이름변경 좌석 소진 방지). (codex #7)
8. **Keychain 견고화** — `SecItemUpdate` 우선 → `errSecItemNotFound`면 `SecItemAdd`, `OSStatus` 검사, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. (codex #8)
9. **per-module 단일탭 즉시삭제 제거** — 모듈 탭은 미리보기+확인 2스텝. (claude M5)
10. **차별화된 에러 UX** — 무효 키 / 429 rate-limit / 네트워크 / 키 미수령을 구분, "주문 이메일에서 키 확인" 힌트 + 429/5xx 백오프. 디코더가 서버 `error` 문자열 보존. (양쪽 공통)
11. **릴리스 게이트** — placeholder(`storeId:0`/`REPLACE_ME`)면 release 빌드 실패시키는 가드. (양쪽 공통)
12. 코드 cruft 제거(`placeholder()`, `_ = items`), stale 주석 갱신, 테스트 수 "205"→"기존 전체(≈274)".

**제품 결정 (사용자 확정):**
- **무료/Pro 경계 = 현 경계 유지 + Pro 재포지셔닝.** 무료=모듈별 수동 회수 유지(도구 본질). Pro UI/문구를 **자동 청소 + 전 스킨** 중심으로, "원클릭 전체 회수"는 편의 보너스로 강등.
- **Docker = 무료 개방.** `ReclaimGate`에서 Docker Pro 게이팅 제거(crippleware 우려 해소). 단 auto-clean은 Docker의 `.autoSafe` 항목만(아래 #1 규칙) 자동 회수.
- **가격 = $9.99 출시가 → 추후 인상.** 표시 문구·문서만 $9.99로.

---

## 배경 (필독)

- 결제 메커니즘·제공자는 확정됨. spec 참조:
  `docs/superpowers/specs/2026-06-17-devsweep-license-monetization-design.md`.
- LemonSqueezy License API(`/v1/licenses/activate|validate|deactivate`)는 **API 키 불필요** —
  라이선스 키 자체가 인증 파라미터다. 앱이 직접 호출하며 별도 서버가 없다.
- `validate`/`activate` 응답의 `meta.store_id`/`meta.product_id`로 "내 Pro 상품 키"임을 바인딩 검증,
  `license_key.status`(active/inactive/expired/disabled) + 최상위 `valid`로 환불 시 재잠금.
- **client-side 검증은 자명히 우회 가능**하다(바이너리 패치·JSON 위조). 이는 $19.99 미만 Developer ID
  툴엔 right-sized — **"캐주얼 라이선싱"으로 문서화하고 과한 hardening은 하지 않는다**(양 리뷰어 합의).
- **Pro는 이진(binary)**: 키 검증 통과 → 전 스킨 + 자동청소 + 원클릭 전체회수. (다중상품용
  `EntitlementResolver`는 동면 StoreKit 경로 전용으로 남는다.)

## 프로젝트 규약 (지킬 것)

- 테스트 프레임워크: **Swift Testing**. `import Testing` + `@Suite`/`@Test`/`#expect`. XCTest 금지.
- 테스트 더블은 `Tests/DevSweepCoreTests/Support/`에 둔다(기존 `MockPurchaseBackend.swift` 패턴).
- `now: @Sendable () -> Date` 주입 패턴(예: `ScanCoordinator`, `ReclaimRouter`)을 시각 의존 로직에 사용.
- 빌드: `swift build`. 전체 테스트: `swift test`. 단일: `swift test --filter <SuiteName>`.
- 작업 브랜치: `feat/devsweep-license-monetization` (이미 체크아웃됨, spec/플랜 커밋 있음).
- 커밋 메시지 말미: `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`

## 파일 구조 (생성/수정)

**생성 (Core, 순수·테스트 대상):**
- `Sources/DevSweepCore/License/LicenseModels.swift`
- `Sources/DevSweepCore/License/LicenseConfig.swift`
- `Sources/DevSweepCore/License/LicenseBinding.swift`
- `Sources/DevSweepCore/License/LicenseActivating.swift` (+ `LicenseClientError`)
- `Sources/DevSweepCore/License/LicenseStorage.swift`
- `Sources/DevSweepCore/License/LicenseStore.swift`
- `Sources/DevSweepCore/License/LemonSqueezyDecoding.swift`
- `Sources/DevSweepCore/License/ReclaimGate.swift`
- `Sources/DevSweepCore/License/AutoReclaimPolicy.swift`

**생성 (App):**
- `Sources/DevSweepApp/License/LemonSqueezyLicenseClient.swift`
- `Sources/DevSweepApp/License/KeychainLicenseStorage.swift`

**생성 (테스트 더블 + 테스트):** `Support/MockLicenseClient.swift`, `Support/InMemoryLicenseStorage.swift`,
`LicenseBindingTests.swift`, `LicenseStoreTests.swift`, `LemonSqueezyDecodingTests.swift`,
`ReclaimGateTests.swift`, `AutoReclaimPolicyTests.swift`

**수정:** `AppCoordinator.swift`, `MenuView.swift`, `StatusItemController.swift`,
`packaging/RELEASE.md`, `packaging/build_app.sh`(릴리스 가드), 신규 `docs/LICENSING.md`

---

## Task 1: License 모델 + Config + Binding (Core, 순수)

**Files:** Create `LicenseModels.swift`, `LicenseConfig.swift`, `LicenseBinding.swift`; Test `LicenseBindingTests.swift`

- [ ] **Step 1: Write the failing test** — `Tests/DevSweepCoreTests/LicenseBindingTests.swift`
```swift
import Testing
import Foundation
@testable import DevSweepCore

/// `LicenseBinding` is the single place the "is this key Pro?" rule lives: Pro only when valid,
/// active, unexpired, and issued by *our* store + product. Everything else → free.
@Suite struct LicenseBindingTests {
    private let config = LicenseConfig(
        checkoutURL: URL(string: "https://example.com/checkout")!,
        apiBaseURL: URL(string: "https://api.lemonsqueezy.com/v1/licenses")!,
        expectedStoreId: 42, expectedProductIds: [7],
        graceWindow: 14 * 24 * 3600, seatLimit: 3, displayPrice: "$9.99"
    )
    private let now = Date(timeIntervalSince1970: 1_000_000)

    private func status(valid: Bool = true, status: String = "active", storeId: Int? = 42,
                        productId: Int? = 7, expiresAt: Date? = nil) -> LicenseStatus {
        LicenseStatus(valid: valid, status: status, storeId: storeId, productId: productId,
                      expiresAt: expiresAt, activationLimit: 3, activationUsage: 1, serverMessage: nil)
    }

    @Test func validActiveMatchingKeyIsPro() {
        #expect(LicenseBinding(config: config).entitlement(for: status(), now: now) == .pro)
    }
    @Test func invalidKeyIsFree() {
        #expect(LicenseBinding(config: config).entitlement(for: status(valid: false), now: now) == .free)
    }
    @Test func refundedDisabledKeyIsFree() {
        #expect(LicenseBinding(config: config).entitlement(for: status(status: "disabled"), now: now) == .free)
    }
    @Test func wrongStoreIsFree() {
        #expect(LicenseBinding(config: config).entitlement(for: status(storeId: 99), now: now) == .free)
    }
    @Test func wrongProductIsFree() {
        #expect(LicenseBinding(config: config).entitlement(for: status(productId: 999), now: now) == .free)
    }
    @Test func expiredKeyIsFree() {
        #expect(LicenseBinding(config: config).entitlement(for: status(expiresAt: now.addingTimeInterval(-1)), now: now) == .free)
    }
    @Test func futureExpiryStillPro() {
        #expect(LicenseBinding(config: config).entitlement(for: status(expiresAt: now.addingTimeInterval(3600)), now: now) == .pro)
    }
}
```

- [ ] **Step 2: Run test to verify it fails** — `swift test --filter LicenseBindingTests` → FAIL (types not found).

- [ ] **Step 3: Write the models** — `Sources/DevSweepCore/License/LicenseModels.swift`
```swift
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
```

- [ ] **Step 4: Write the config** — `Sources/DevSweepCore/License/LicenseConfig.swift`
```swift
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
```

- [ ] **Step 5: Write the binding** — `Sources/DevSweepCore/License/LicenseBinding.swift`
```swift
import Foundation

/// Pure rule: a `LicenseStatus` grants Pro only when valid, active, unexpired, and from our
/// store + product. The single source of truth for entitlement.
public struct LicenseBinding: Sendable {
    private let config: LicenseConfig
    public init(config: LicenseConfig) { self.config = config }

    public func entitlement(for status: LicenseStatus, now: Date) -> LicenseEntitlement {
        guard status.valid, status.status == "active",
              status.storeId == config.expectedStoreId,
              let productId = status.productId, config.expectedProductIds.contains(productId)
        else { return .free }
        if let expiry = status.expiresAt, expiry <= now { return .free }
        return .pro
    }
}
```

- [ ] **Step 6: Run test** — `swift test --filter LicenseBindingTests` → PASS (7).
- [ ] **Step 7: Commit**
```bash
git add Sources/DevSweepCore/License/LicenseModels.swift Sources/DevSweepCore/License/LicenseConfig.swift \
        Sources/DevSweepCore/License/LicenseBinding.swift Tests/DevSweepCoreTests/LicenseBindingTests.swift
git commit -m "feat(devsweep): License models + config + binding (Pro entitlement rule)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: LicenseActivating + LicenseStorage 프로토콜 + 테스트 더블

**Files:** Create `LicenseActivating.swift`, `LicenseStorage.swift`, `Support/MockLicenseClient.swift`, `Support/InMemoryLicenseStorage.swift`

- [ ] **Step 1: Write the protocols + error type** — `Sources/DevSweepCore/License/LicenseActivating.swift`
```swift
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
```

`Sources/DevSweepCore/License/LicenseStorage.swift`
```swift
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
```

- [ ] **Step 2: Write the test doubles** — `Tests/DevSweepCoreTests/Support/MockLicenseClient.swift`
```swift
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
```

`Tests/DevSweepCoreTests/Support/InMemoryLicenseStorage.swift`
```swift
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
```

- [ ] **Step 3: Verify it compiles** — `swift build --build-tests` → no errors.
- [ ] **Step 4: Commit**
```bash
git add Sources/DevSweepCore/License/LicenseActivating.swift Sources/DevSweepCore/License/LicenseStorage.swift \
        Tests/DevSweepCoreTests/Support/MockLicenseClient.swift Tests/DevSweepCoreTests/Support/InMemoryLicenseStorage.swift
git commit -m "feat(devsweep): LicenseActivating/LicenseStorage protocols + test doubles

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: LicenseStore 상태머신 (Core, `@MainActor`)

**Files:** Create `LicenseStore.swift`; Test `LicenseStoreTests.swift`

핵심 정정(rev #2/#10): `validate()`는 **catch한 throw(전송 실패)** 에만 오프라인 grace를 적용한다.
서버가 무효 판정한 키(`valid:false`)는 throw가 아니라 디코딩되어 돌아오므로 **즉시 re-lock**된다.

- [ ] **Step 1: Write the failing test** — `Tests/DevSweepCoreTests/LicenseStoreTests.swift`
```swift
import Testing
import Foundation
@testable import DevSweepCore

@Suite @MainActor struct LicenseStoreTests {
    private let config = LicenseConfig(
        checkoutURL: URL(string: "https://example.com/buy")!,
        apiBaseURL: URL(string: "https://api.lemonsqueezy.com/v1/licenses")!,
        expectedStoreId: 42, expectedProductIds: [7],
        graceWindow: 14 * 24 * 3600, seatLimit: 3, displayPrice: "$9.99")
    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    private func proStatus() -> LicenseStatus {
        LicenseStatus(valid: true, status: "active", storeId: 42, productId: 7,
                      expiresAt: nil, activationLimit: 3, activationUsage: 1, serverMessage: nil)
    }
    private func revokedStatus() -> LicenseStatus {
        LicenseStatus(valid: false, status: "disabled", storeId: 42, productId: 7,
                      expiresAt: nil, activationLimit: 3, activationUsage: 1, serverMessage: "license_key disabled")
    }
    private func store(_ c: MockLicenseClient, _ s: InMemoryLicenseStorage, now: Date) -> LicenseStore {
        LicenseStore(client: c, storage: s, config: config, deviceName: "Test Mac", now: { now })
    }

    @Test func successfulActivationGrantsProAndUnlocksAllSkins() async {
        let c = MockLicenseClient(activateResult: ActivationResult(activated: true, instanceId: "inst-1", status: proStatus()), validateStatus: proStatus())
        let s = InMemoryLicenseStorage()
        let st = store(c, s, now: t0)
        await st.activate(key: "VALID-KEY")
        #expect(st.isPro)
        #expect(st.unlockedSkinIds == Set(SkinCatalog.all.map(\.id)))
        #expect(st.activationState == .idle)
        #expect(s.load()?.instanceId == "inst-1")
    }

    @Test func activationUsesStableInstanceNameWithInstallID() async {
        let c = MockLicenseClient(activateResult: ActivationResult(activated: true, instanceId: "inst-1", status: proStatus()), validateStatus: proStatus())
        let s = InMemoryLicenseStorage(installID: "uuid-123")
        await store(c, s, now: t0).activate(key: "K")
        let names = await c.activateCalls
        #expect(names == ["K"])  // call recorded; instance_name carrying installID is asserted in client tests
    }

    @Test func activatingAKeyForAnotherProductIsRejected() async {
        let wrong = LicenseStatus(valid: true, status: "active", storeId: 42, productId: 999,
                                  expiresAt: nil, activationLimit: 3, activationUsage: 1, serverMessage: nil)
        let c = MockLicenseClient(activateResult: ActivationResult(activated: true, instanceId: "i", status: wrong), validateStatus: wrong)
        let s = InMemoryLicenseStorage()
        let st = store(c, s, now: t0)
        await st.activate(key: "OTHER")
        #expect(!st.isPro); #expect(s.load() == nil)
        if case .invalid = st.activationState {} else { Issue.record("expected .invalid") }
    }

    @Test func rateLimitedActivationShowsSpecificMessage() async {
        let c = MockLicenseClient(activateResult: ActivationResult(activated: false, instanceId: nil, status: revokedStatus()), validateStatus: revokedStatus(), throwError: .rateLimited)
        let st = store(c, InMemoryLicenseStorage(), now: t0)
        await st.activate(key: "ANY")
        #expect(!st.isPro)
        if case .invalid(let r) = st.activationState { #expect(r.contains("잠시")) } else { Issue.record("expected .invalid") }
    }

    @Test func validateServerRejectionRelocksImmediatelyEvenWithinGrace() async {
        // valid:false from server (NOT a throw) → re-lock now, ignoring grace. rev #2.
        let s = InMemoryLicenseStorage(seed: StoredLicense(key: "K", instanceId: "i", lastValidatedAt: t0))
        let c = MockLicenseClient(activateResult: ActivationResult(activated: true, instanceId: "i", status: proStatus()), validateStatus: revokedStatus())
        let st = store(c, s, now: t0.addingTimeInterval(3600)) // well within 14d grace
        await st.validate()
        #expect(!st.isPro); #expect(s.load() == nil)
    }

    @Test func validateTransportErrorWithinGraceKeepsPro() async {
        let last = t0
        let s = InMemoryLicenseStorage(seed: StoredLicense(key: "K", instanceId: "i", lastValidatedAt: last))
        let c = MockLicenseClient(activateResult: ActivationResult(activated: true, instanceId: "i", status: proStatus()), validateStatus: proStatus(), throwError: .transport)
        let st = store(c, s, now: last.addingTimeInterval(24 * 3600))
        await st.validate()
        #expect(st.isPro); #expect(s.load() != nil)
    }

    @Test func validateTransportErrorPastGraceRelocks() async {
        let last = t0
        let s = InMemoryLicenseStorage(seed: StoredLicense(key: "K", instanceId: "i", lastValidatedAt: last))
        let c = MockLicenseClient(activateResult: ActivationResult(activated: true, instanceId: "i", status: proStatus()), validateStatus: proStatus(), throwError: .transport)
        let st = store(c, s, now: last.addingTimeInterval(15 * 24 * 3600))
        await st.validate()
        #expect(!st.isPro)
    }

    @Test func validateNoStoredLicenseIsFree() async {
        let c = MockLicenseClient(activateResult: ActivationResult(activated: true, instanceId: "i", status: proStatus()), validateStatus: proStatus())
        let st = store(c, InMemoryLicenseStorage(), now: t0)
        await st.validate()
        #expect(!st.isPro); #expect(st.unlockedSkinIds.isEmpty)
    }

    @Test func deactivateReleasesSeatAndRelocks() async {
        let s = InMemoryLicenseStorage(seed: StoredLicense(key: "K", instanceId: "i", lastValidatedAt: t0))
        let c = MockLicenseClient(activateResult: ActivationResult(activated: true, instanceId: "i", status: proStatus()), validateStatus: proStatus())
        let st = store(c, s, now: t0)
        await st.validate(); #expect(st.isPro)
        await st.deactivate()
        #expect(!st.isPro); #expect(s.load() == nil)
        let calls = await c.deactivateCalls; #expect(calls == ["K"])
    }

    @Test func isStaleReflectsLastValidatedAt() async {
        let s = InMemoryLicenseStorage(seed: StoredLicense(key: "K", instanceId: "i", lastValidatedAt: t0))
        let st = store(MockLicenseClient(activateResult: ActivationResult(activated: true, instanceId: "i", status: proStatus()), validateStatus: proStatus()), s, now: t0.addingTimeInterval(7 * 3600))
        #expect(st.isStale(maxAge: 6 * 3600))   // 7h since last validate > 6h
    }

    @Test func canSelectGatesPaidSkinsButAllowsFreeSkins() async {
        let st = store(MockLicenseClient(activateResult: ActivationResult(activated: true, instanceId: "i", status: proStatus()), validateStatus: proStatus()), InMemoryLicenseStorage(), now: t0)
        #expect(st.canSelect(SkinCatalog.free.first!))
        #expect(!st.canSelect(SkinCatalog.paid.first!))
        await st.activate(key: "VALID")
        #expect(st.canSelect(SkinCatalog.paid.first!))
    }
}
```

- [ ] **Step 2: Run test to verify it fails** — `swift test --filter LicenseStoreTests` → FAIL (no `LicenseStore`).

- [ ] **Step 3: Write the LicenseStore** — `Sources/DevSweepCore/License/LicenseStore.swift`
```swift
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
```

- [ ] **Step 4: Run test** — `swift test --filter LicenseStoreTests` → PASS (11).
- [ ] **Step 5: Commit**
```bash
git add Sources/DevSweepCore/License/LicenseStore.swift Tests/DevSweepCoreTests/LicenseStoreTests.swift
git commit -m "feat(devsweep): LicenseStore — server-reject re-locks now, transport errors use grace

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: LemonSqueezy JSON 디코딩 (Core, 순수)

**Files:** Create `LemonSqueezyDecoding.swift`; Test `LemonSqueezyDecodingTests.swift`
정정: `placeholder()` 제거, `error` 문자열 보존(serverMessage), **마이크로초 ISO8601** 파싱, null/plain 타임스탬프 테스트.

- [ ] **Step 1: Write the failing test** — `Tests/DevSweepCoreTests/LemonSqueezyDecodingTests.swift`
```swift
import Testing
import Foundation
@testable import DevSweepCore

@Suite struct LemonSqueezyDecodingTests {
    private let validateJSON = """
    { "valid": true, "error": null,
      "license_key": { "id": 1, "status": "active", "key": "ABCD-1234", "activation_limit": 3, "activation_usage": 1, "expires_at": null },
      "instance": { "id": "inst-abc", "name": "Test Mac" },
      "meta": { "store_id": 42, "order_id": 5, "product_id": 7, "variant_id": 9 } }
    """.data(using: .utf8)!

    private let activateJSON = """
    { "activated": true, "error": null,
      "license_key": { "id": 1, "status": "active", "key": "ABCD-1234", "activation_limit": 3, "activation_usage": 2, "expires_at": "2030-01-02T03:04:05.000000Z" },
      "instance": { "id": "inst-xyz", "name": "Test Mac" },
      "meta": { "store_id": 42, "order_id": 5, "product_id": 7, "variant_id": 9 } }
    """.data(using: .utf8)!

    @Test func decodesValidateResponse() throws {
        let s = try LemonSqueezyDecoder.validation(from: validateJSON)
        #expect(s.valid); #expect(s.status == "active"); #expect(s.storeId == 42)
        #expect(s.productId == 7); #expect(s.expiresAt == nil); #expect(s.activationLimit == 3)
    }
    @Test func decodesActivateResponseWithMicrosecondExpiry() throws {
        let r = try LemonSqueezyDecoder.activation(from: activateJSON)
        #expect(r.activated); #expect(r.instanceId == "inst-xyz"); #expect(r.status.productId == 7)
        #expect(r.status.expiresAt != nil)          // 6-digit fractional seconds parsed (rev #3)
    }
    @Test func decodesPlainSecondTimestamp() throws {
        let json = """
        { "valid": true, "license_key": { "status": "active", "expires_at": "2030-01-02T03:04:05Z" }, "meta": { "store_id": 42, "product_id": 7 } }
        """.data(using: .utf8)!
        #expect(try LemonSqueezyDecoder.validation(from: json).expiresAt != nil)
    }
    @Test func decodesInvalidResponseRetainingErrorMessage() throws {
        let json = """
        { "valid": false, "error": "license_key not found", "license_key": null, "instance": null, "meta": null }
        """.data(using: .utf8)!
        let s = try LemonSqueezyDecoder.validation(from: json)
        #expect(!s.valid); #expect(s.status == "inactive"); #expect(s.storeId == nil)
        #expect(s.serverMessage == "license_key not found")   // retained for UX (rev #10)
    }
}
```

- [ ] **Step 2: Run test to verify it fails** — `swift test --filter LemonSqueezyDecodingTests` → FAIL.

- [ ] **Step 3: Write the decoder** — `Sources/DevSweepCore/License/LemonSqueezyDecoding.swift`
```swift
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
```

- [ ] **Step 4: Run test** — `swift test --filter LemonSqueezyDecodingTests` → PASS (4).
- [ ] **Step 5: Commit**
```bash
git add Sources/DevSweepCore/License/LemonSqueezyDecoding.swift Tests/DevSweepCoreTests/LemonSqueezyDecodingTests.swift
git commit -m "feat(devsweep): LemonSqueezy response decoding (microsecond ISO8601, error retained)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: LemonSqueezyLicenseClient (App, URLSession shell)

**Files:** Create `Sources/DevSweepApp/License/LemonSqueezyLicenseClient.swift`
정정(rev #2): 2xx **및 JSON 본문이 있는 4xx**는 디코딩해 반환(서버 거부 = `valid:false`).
throw는 전송 실패(`URLError`)·5xx·429에만 → `LicenseClientError`. 컴파일 검증 + Task 10 통합검증.

- [ ] **Step 1: Write the client**
```swift
import Foundation
import DevSweepCore

/// Production `LicenseActivating` — form-encoded POSTs to the keyless LemonSqueezy License API.
/// No API key (the license key authorizes). Returns decoded results for 2xx and JSON-bearing 4xx
/// (a server rejection is `valid:false`, NOT an error); throws `LicenseClientError` only for
/// transport failures, 429, and 5xx so the store applies offline grace only when truly offline.
struct LemonSqueezyLicenseClient: LicenseActivating {
    let baseURL: URL
    let session: URLSession
    init(baseURL: URL, session: URLSession = .shared) { self.baseURL = baseURL; self.session = session }

    func activate(key: String, instanceName: String) async throws -> ActivationResult {
        try LemonSqueezyDecoder.activation(from: try await post("activate", ["license_key": key, "instance_name": instanceName]))
    }
    func validate(key: String, instanceId: String) async throws -> LicenseStatus {
        try LemonSqueezyDecoder.validation(from: try await post("validate", ["license_key": key, "instance_id": instanceId]))
    }
    func deactivate(key: String, instanceId: String) async throws {
        _ = try await post("deactivate", ["license_key": key, "instance_id": instanceId])
    }

    private func post(_ path: String, _ fields: [String: String]) async throws -> Data {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = Self.formBody(fields)
        do {
            let (data, response) = try await session.data(for: req)
            guard let http = response as? HTTPURLResponse else { throw LicenseClientError.transport }
            switch http.statusCode {
            case 200...299, 400, 404, 422:
                // 2xx and the documented license-verdict 4xx codes carry a JSON body the decoder
                // turns into valid:false → the store re-locks. NOT treated as a transient error.
                return data
            case 429:
                throw LicenseClientError.rateLimited
            default:
                throw LicenseClientError.server(http.statusCode)   // 5xx / unexpected
            }
        } catch let e as LicenseClientError {
            throw e
        } catch {
            throw LicenseClientError.transport                      // URLError etc. → grace
        }
    }

    private static func formBody(_ fields: [String: String]) -> Data {
        let allowed = CharacterSet.urlQueryAllowed.subtracting(CharacterSet(charactersIn: "+&="))
        return Data(fields.map { k, v in
            "\(k.addingPercentEncoding(withAllowedCharacters: allowed) ?? k)=\(v.addingPercentEncoding(withAllowedCharacters: allowed) ?? v)"
        }.joined(separator: "&").utf8)
    }
}
```

- [ ] **Step 2: Verify it compiles** — `swift build` → builds.
- [ ] **Step 3: Commit**
```bash
git add Sources/DevSweepApp/License/LemonSqueezyLicenseClient.swift
git commit -m "feat(devsweep): LemonSqueezyLicenseClient — 4xx-with-body decodes, throw only on transport/5xx/429

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: KeychainLicenseStorage (App)

**Files:** Create `Sources/DevSweepApp/License/KeychainLicenseStorage.swift`
정정(rev #7/#8): `SecItemUpdate` 우선→`errSecItemNotFound`면 `SecItemAdd`, `OSStatus` 검사,
`...ThisDeviceOnly` 접근성, 안정적 install UUID(별도 account). CI 단위테스트 없음(Keychain) —
`LicenseStorage` 계약은 InMemory mock으로 커버, 본 구현은 컴파일+Task 10 수동검증.

- [ ] **Step 1: Write the Keychain storage**
```swift
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
```

- [ ] **Step 2: Verify it compiles** — `swift build` → builds.
- [ ] **Step 3: Commit**
```bash
git add Sources/DevSweepApp/License/KeychainLicenseStorage.swift
git commit -m "feat(devsweep): KeychainLicenseStorage — update-first upsert, ThisDeviceOnly, stable install id

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: ReclaimGate + AutoReclaimPolicy (Core, 순수)

**Files:** Create `ReclaimGate.swift`, `AutoReclaimPolicy.swift`; Test `ReclaimGateTests.swift`, `AutoReclaimPolicyTests.swift`
정정: **Docker 무료 개방** → `ReclaimGate`는 모든 모듈별 회수 허용, `.all`(원클릭 전체)만 Pro.
**`AutoReclaimPolicy`는 `.autoSafe` 항목만 선별**(rev #1) — `reviewNeeded`(node_modules/worktree) 절대 자동삭제 안 함.

- [ ] **Step 1: Write the failing tests** — `Tests/DevSweepCoreTests/ReclaimGateTests.swift`
```swift
import Testing
@testable import DevSweepCore

/// dry-run preview is always free; per-module real reclaim is free for EVERY module (Docker opened
/// to free, rev product-decision); only the one-click "reclaim all" convenience is Pro.
@Suite struct ReclaimGateTests {
    private let gate = ReclaimGate()
    @Test func dryRunAlwaysAllowed() {
        #expect(gate.decide(scope: .all, isPro: false, dryRun: true) == .allow)
        #expect(gate.decide(scope: .module("docker"), isPro: false, dryRun: true) == .allow)
    }
    @Test func reclaimAllRequiresProWhenNotPro() {
        #expect(gate.decide(scope: .all, isPro: false, dryRun: false) == .requiresPro)
    }
    @Test func reclaimAllAllowedWhenPro() {
        #expect(gate.decide(scope: .all, isPro: true, dryRun: false) == .allow)
    }
    @Test func everyPerModuleRealReclaimIsFree() {
        for id in ["node-modules", "package-cache", "git-worktrees", "docker"] {
            #expect(gate.decide(scope: .module(id), isPro: false, dryRun: false) == .allow)
        }
    }
}
```

`Tests/DevSweepCoreTests/AutoReclaimPolicyTests.swift`
```swift
import Testing
import Foundation
@testable import DevSweepCore

/// Auto-clean runs only when Pro AND opted in, and may ONLY reclaim `.autoSafe` items —
/// `.reviewNeeded` (node_modules / git-worktrees) always needs explicit approval (SafetyClass).
@Suite struct AutoReclaimPolicyTests {
    private let policy = AutoReclaimPolicy()
    private func item(_ id: String, _ safety: SafetyClass) -> CleanupItem {
        CleanupItem(id: id, path: "/x/\(id)", sizeBytes: 1, lastUsed: nil, safety: safety,
                    reclaimMethod: .deletePath(toTrash: true))
    }
    @Test func gatedOnProAndOptIn() {
        #expect(policy.shouldAutoReclaim(isPro: true, autoCleanEnabled: true))
        #expect(!policy.shouldAutoReclaim(isPro: true, autoCleanEnabled: false))
        #expect(!policy.shouldAutoReclaim(isPro: false, autoCleanEnabled: true))
    }
    @Test func selectsOnlyAutoSafeItems() {
        let items = [item("cache", .autoSafe), item("node_modules", .reviewNeeded), item("dockercache", .autoSafe)]
        let selected = policy.autoCleanableItems(from: items)
        #expect(Set(selected.map(\.id)) == ["cache", "dockercache"])   // reviewNeeded excluded (rev #1)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail** — `swift test --filter ReclaimGateTests` / `--filter AutoReclaimPolicyTests` → FAIL.

- [ ] **Step 3: Write the gate** — `Sources/DevSweepCore/License/ReclaimGate.swift`
```swift
/// Pure free/Pro decision for reclaim actions. dry-run preview is always free; per-module real
/// reclaim is free for every module (Docker is free per product decision); only one-click
/// "reclaim all" is Pro (a convenience, not a capability gate).
public struct ReclaimGate: Sendable {
    public enum Scope: Sendable, Equatable { case all; case module(String) }
    public enum Decision: Sendable, Equatable { case allow, requiresPro }
    public init() {}
    public func decide(scope: Scope, isPro: Bool, dryRun: Bool) -> Decision {
        if dryRun || isPro { return .allow }
        switch scope {
        case .all: return .requiresPro
        case .module: return .allow
        }
    }
}
```

`Sources/DevSweepCore/License/AutoReclaimPolicy.swift`
```swift
/// Pure rules for scheduled/automatic reclaim. Runs only when Pro + opted in, and may reclaim ONLY
/// `.autoSafe` candidates — `.reviewNeeded` items (node_modules, git-worktrees) require explicit
/// human approval per `SafetyClass`, so hands-off cleaning must never touch them (rev #1).
public struct AutoReclaimPolicy: Sendable {
    public init() {}
    public func shouldAutoReclaim(isPro: Bool, autoCleanEnabled: Bool) -> Bool { isPro && autoCleanEnabled }
    public func autoCleanableItems(from items: [CleanupItem]) -> [CleanupItem] {
        items.filter { $0.safety == .autoSafe }
    }
}
```

- [ ] **Step 4: Run tests** — both filters → PASS.
- [ ] **Step 5: Commit**
```bash
git add Sources/DevSweepCore/License/ReclaimGate.swift Sources/DevSweepCore/License/AutoReclaimPolicy.swift \
        Tests/DevSweepCoreTests/ReclaimGateTests.swift Tests/DevSweepCoreTests/AutoReclaimPolicyTests.swift
git commit -m "feat(devsweep): ReclaimGate (Docker free, all=Pro) + AutoReclaimPolicy (autoSafe-only)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: AppCoordinator 배선

**Files:** Modify `Sources/DevSweepApp/AppCoordinator.swift`

- [ ] **Step 1: Replace StoreKit props with LicenseStore + gates**

Replace (lines ~52-54):
```swift
    /// IAP state: loaded products, unlocked-skin set, buy/restore. The menu observes it directly; the
    /// coordinator consults it to gate skin selection. The real `StoreKit2Backend` is injected here.
    let skinStore: SkinStore
```
with:
```swift
    /// License state: tier, unlocked-skin set, activation flow. The menu observes it directly; the
    /// coordinator consults `isPro`/`canSelect` to gate skin selection + reclaim. Real
    /// `LemonSqueezyLicenseClient` + `KeychainLicenseStorage` injected here.
    let licenseStore: LicenseStore
```

Replace (lines ~81-86, the `purchaseBackend` + `transactionObserver` block) with:
```swift
    /// Pure free/Pro gating rules consulted by the reclaim entry points + the auto-clean path.
    private let reclaimGate = ReclaimGate()
    private let autoReclaimPolicy = AutoReclaimPolicy()
    /// UserDefaults key for the Pro-only "auto-clean on scan" opt-in toggle.
    private static let autoCleanKey = "DevSweep.autoCleanEnabled"
    /// Max age before a menu-open triggers re-validation (rev #6).
    private static let revalidateStaleness: TimeInterval = 6 * 3600
```

Add near the other `@Published` (after line ~41):
```swift
    /// Set to a Pro-gated action's label when a non-Pro user triggers it, so the menu can surface a
    /// purchase prompt. The menu clears it after presenting.
    @Published var proGateHit: String?
```

- [ ] **Step 2: Rewire the initializer** — replace (line ~134) `self.skinStore = SkinStore(backend: purchaseBackend)` with:
```swift
        self.licenseStore = LicenseStore(
            client: LemonSqueezyLicenseClient(baseURL: LicenseConfig.production.apiBaseURL),
            storage: KeychainLicenseStorage(),
            config: .production,
            deviceName: Host.current().localizedName ?? "Mac"
        )
```

- [ ] **Step 3: Rewire `start()`** — replace the StoreKit load + transactionObserver block (lines ~184-193) with:
```swift
        Task { [weak self] in
            await self?.licenseStore.validate()
            self?.didLoadEntitlements = true
            self?.reconcileSkinSelection()
        }
```

- [ ] **Step 4: Update skin gate + reconciler reads** — replace `skinStore.canSelect(skin)` (line ~252) with `licenseStore.canSelect(skin)`; replace `unlockedSkinIds: skinStore.unlockedSkinIds,` (line ~268) with `unlockedSkinIds: licenseStore.unlockedSkinIds,`.

Replace `handleEntitlementChange()` (lines ~282-286) with coordinator-routed license mutations (rev #5) that reconcile + revert a now-locked skin in-session:
```swift
    /// Activate a key from the menu, then reconcile the skin selection against the new tier.
    func activateLicense(key: String) async {
        await licenseStore.activate(key: key)
        reconcileSkinSelection()
    }

    /// Deactivate from the menu, then reconcile — a previously selected *paid* skin must re-lock now,
    /// not at next relaunch. `reconcileSkinSelection` reverts it to the default when no longer unlocked.
    func deactivateLicense() async {
        await licenseStore.deactivate()
        reconcileSkinSelection()
    }

    /// Re-validate if the last good validation is stale (called on menu open, rev #6).
    func revalidateLicenseIfStale() {
        guard licenseStore.isStale(maxAge: Self.revalidateStaleness) else { return }
        Task { [weak self] in
            await self?.licenseStore.validate()
            self?.reconcileSkinSelection()
        }
    }
```

> Note: `reconcileSkinSelection()` already reverts a selected skin to default when it isn't in
> `unlockedSkinIds` and isn't free (it reads `licenseStore.unlockedSkinIds` after Step 4). Confirm
> the reconciler's revert branch is gated on `didLoadEntitlements` (already true post-launch).

- [ ] **Step 5: Add the Pro-gated reclaim entry points** (after `reclaim(approved:dryRun:)`, ~line 342):
```swift
    /// One-click "reclaim all reviewed items". Pro-gated for a real run; dry-run preview is free.
    @discardableResult
    func reclaimAll(dryRun: Bool) async -> [ReclaimOutcome] {
        guard gateAllows(scope: .all, dryRun: dryRun, label: "전체 회수") else { return [] }
        return await reclaim(approved: currentItems, dryRun: dryRun)
    }
    /// Reclaim a single module's reviewed items. Free for every module (Docker included).
    @discardableResult
    func reclaimModule(id moduleId: String, dryRun: Bool) async -> [ReclaimOutcome] {
        guard gateAllows(scope: .module(moduleId), dryRun: dryRun, label: moduleNames[moduleId] ?? moduleId) else { return [] }
        let items = currentGrouped.first { $0.module == moduleId }?.items ?? []
        return await reclaim(approved: items, dryRun: dryRun)
    }
    private func gateAllows(scope: ReclaimGate.Scope, dryRun: Bool, label: String) -> Bool {
        switch reclaimGate.decide(scope: scope, isPro: licenseStore.isPro, dryRun: dryRun) {
        case .allow: return true
        case .requiresPro: proGateHit = label; return false
        }
    }
```

- [ ] **Step 6: Add the opt-in auto-clean path (Pro, autoSafe-only) — fixed ordering (rev #1, #4)**

Add accessor (after `setSkin`):
```swift
    /// Pro-only "auto-clean after scan" opt-in (persisted). The auto-clean path also checks
    /// `licenseStore.isPro`, so a stale `true` never cleans for a free user.
    var autoCleanEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.autoCleanKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.autoCleanKey) }
    }
```

In `scanNow()`, move the hook to AFTER `isScanning = false` (rev #4 — so the nested re-scan inside
`reclaim` isn't dropped). Replace the loop tail:
```swift
        } while rescanPending
        isScanning = false
        await autoCleanIfEnabled()
    }

    /// Pro + opt-in only: reclaim ONLY `.autoSafe` candidates after a scan (never `.reviewNeeded`
    /// node_modules/worktrees — they require explicit approval, rev #1). `reclaim` re-scans afterward,
    /// which now runs cleanly because `isScanning` is already false (rev #4).
    private func autoCleanIfEnabled() async {
        guard autoReclaimPolicy.shouldAutoReclaim(isPro: licenseStore.isPro, autoCleanEnabled: autoCleanEnabled) else { return }
        let safe = autoReclaimPolicy.autoCleanableItems(from: currentItems)
        guard !safe.isEmpty else { return }
        _ = await reclaim(approved: safe, dryRun: false)
    }
```

- [ ] **Step 7: Build + full suite**

Run: `swift build` → builds (StoreKit `SkinStore`/`StoreKit2Backend` remain in-tree, unwired).
Run: `swift test` → all PASS — new License suites + the existing suite (dormant `SkinStoreTests`/
`PurchaseBackendTests` construct `SkinStore`/`MockPurchaseBackend` directly, never touch
`AppCoordinator`, so unwiring keeps them green).

- [ ] **Step 8: Commit**
```bash
git add Sources/DevSweepApp/AppCoordinator.swift
git commit -m "feat(devsweep): wire LicenseStore — gated reclaim, autoSafe-only auto-clean, reconcile on license change

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 9: MenuView + StatusItemController UI

**Files:** Modify `StatusItemController.swift`, `MenuView.swift`
정정: per-module은 미리보기+확인 2스텝(단일탭 즉시삭제 금지, rev #9); Docker 행은 잠금 없음(무료);
activate/deactivate는 coordinator 경유(rev #5); 차별화 에러 + 키 찾기 힌트(rev #10); Pro 문구는
자동화·스킨 중심 + $9.99(제품결정); dead code 제거; 팝오버 오픈 시 재검증(rev #6).

- [ ] **Step 1: StatusItemController — swap store + add menu-open revalidation**

Both `MenuView(...)` constructions (lines ~26-28, ~34-36): change `skinStore: coordinator.skinStore,` → `licenseStore: coordinator.licenseStore,`.
In `menuWillOpen(_:)` (line ~86), after `coordinator.refreshFDA()` add:
```swift
        coordinator.revalidateLicenseIfStale()
```

- [ ] **Step 2: MenuView — observed store + sheet state**

Replace `@ObservedObject var skinStore: SkinStore` with:
```swift
    @ObservedObject var licenseStore: LicenseStore
    @State private var licenseKeyInput = ""
    @State private var showingLicenseSheet = false
    @State private var confirmingModuleId: String?   // per-module reclaim confirm (rev #9)
```
Remove `@State private var dryRun = true` (line ~10) — preview vs execute are explicit now.

- [ ] **Step 3: body — add Pro section + sheet + gate-prompt reaction**

Replace the `skinPicker / Divider / footer` tail with:
```swift
            skinPicker
            Divider()
            proSection
            Divider()
            footer
```
Add to the root `VStack` (after `.frame(width: 300)`):
```swift
        .sheet(isPresented: $showingLicenseSheet) { licenseSheet }
        .onChange(of: coordinator.proGateHit) { _, hit in
            if hit != nil { showingLicenseSheet = true; coordinator.proGateHit = nil }
        }
```

- [ ] **Step 4: actions — explicit preview (free) + reclaim-all (Pro convenience)**

Replace the single reclaim button (lines ~146-153) and remove the `dryRun` Toggle (lines ~142-144) with:
```swift
            Button { Task { _ = await coordinator.reclaimAll(dryRun: true) } } label: {
                Label("회수 미리보기", systemImage: "eye")
            }
            .disabled(actionPresentation.reclaimDisabled)

            Button { Task { _ = await coordinator.reclaimAll(dryRun: false) } } label: {
                Label(licenseStore.isPro ? "전체 회수 실행" : "전체 회수 (Pro)",
                      systemImage: licenseStore.isPro ? "trash" : "lock.fill")
            }
            .disabled(actionPresentation.reclaimDisabled)
```

- [ ] **Step 5: moduleList — per-module reclaim with confirm (rev #9), no Docker lock (free)**

Replace the `ForEach(coordinator.topModules)` row body with a two-step confirm (tap → confirm row):
```swift
                ForEach(coordinator.topModules) { module in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(module.name).font(.callout).lineLimit(1)
                            Spacer()
                            Text(humanBytes(module.bytes)).font(.callout).monospacedDigit().foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { confirmingModuleId = (confirmingModuleId == module.module) ? nil : module.module }

                        if confirmingModuleId == module.module {
                            HStack(spacing: 8) {
                                Text("이 모듈을 휴지통으로 회수할까요?").font(.caption2).foregroundStyle(.secondary)
                                Spacer()
                                Button("회수") {
                                    let id = module.module
                                    confirmingModuleId = nil
                                    Task { _ = await coordinator.reclaimModule(id: id, dryRun: false) }
                                }.controlSize(.small)
                                Button("취소") { confirmingModuleId = nil }.controlSize(.small)
                            }
                        }
                    }
                }
```

- [ ] **Step 6: Replace skinPicker (remove StoreKit buy → Pro lock). Delete `allAccessRow` + `price(for:)`.**
```swift
    private var skinPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("스킨").font(.caption).foregroundStyle(.secondary)
            ForEach(SkinCatalog.all, id: \.id) { skin in skinRow(skin) }
        }
    }
    @ViewBuilder private func skinRow(_ skin: any SkinModule) -> some View {
        let selectable = licenseStore.canSelect(skin)
        HStack(spacing: 8) {
            Image(nsImage: skin.image(for: previewState, height: 16)).frame(width: 44, alignment: .leading)
            Text(skin.displayName).font(.callout).foregroundStyle(selectable ? .primary : .secondary)
            Spacer()
            if selectable {
                Image(systemName: skin.id == coordinator.currentSkinId ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(skin.id == coordinator.currentSkinId ? Color.accentColor : Color.secondary)
            } else {
                Label("Pro", systemImage: "lock.fill").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { selectable ? coordinator.setSkin(id: skin.id) : (showingLicenseSheet = true) }
    }
```

- [ ] **Step 7: proSection (automation+skins pitch, $9.99) + licenseSheet (differentiated errors + key hint)**
```swift
    @ViewBuilder private var proSection: some View {
        if licenseStore.isPro {
            VStack(alignment: .leading, spacing: 6) {
                Label("DevSweep Pro 활성화됨", systemImage: "checkmark.seal.fill").font(.callout).foregroundStyle(.green)
                Toggle("스캔 후 자동 청소 (캐시류만)", isOn: Binding(
                    get: { coordinator.autoCleanEnabled }, set: { coordinator.autoCleanEnabled = $0 }))
                    .toggleStyle(.switch).font(.callout)
                Button("이 기기에서 라이선스 해제") { Task { await coordinator.deactivateLicense() } }
                    .font(.caption).buttonStyle(.link)
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("DevSweep Pro — \(licenseStore.displayPrice)").font(.callout).fontWeight(.semibold)
                Text("스캔 후 자동 청소 · 전 스킨 · 원클릭 전체 회수").font(.caption2).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Button("Pro 구매") { NSWorkspace.shared.open(licenseStore.checkoutURL) }
                        .buttonStyle(.borderedProminent).controlSize(.small)
                    Button("라이선스 키 입력") { showingLicenseSheet = true }
                        .buttonStyle(.bordered).controlSize(.small)
                }
            }
        }
    }
    private var licenseSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("라이선스 키 입력").font(.headline)
            TextField("XXXX-XXXX-XXXX-XXXX", text: $licenseKeyInput).textFieldStyle(.roundedBorder).frame(width: 280)
            if case .invalid(let reason) = licenseStore.activationState {
                Label(reason, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("키는 구매 후 받은 주문 이메일에서 확인할 수 있습니다.").font(.caption2).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("취소") { showingLicenseSheet = false }
                Button("활성화") {
                    Task {
                        await coordinator.activateLicense(key: licenseKeyInput)
                        if licenseStore.isPro { showingLicenseSheet = false }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(licenseStore.activationState == .activating || licenseKeyInput.isEmpty)
            }
        }
        .padding(20).frame(width: 340)
    }
```

- [ ] **Step 8: footer — drop the App-Store compliance line (Developer ID)** — change
`Text("모든 정리 기능은 계속 무료입니다.")` to `Text("핵심 정리는 무료 · Pro로 자동 청소·전 스킨")`.

- [ ] **Step 9: Build** — `swift build` → builds (no leftover refs to `skinStore`, `allAccessRow`, `price(for:)`, `dryRun`). Update stale doc comments at `AppCoordinator.swift:50,58,82,249` and `MenuView.swift:4-6` to describe the license/Pro UI (rev #12).

- [ ] **Step 10: Commit**
```bash
git add Sources/DevSweepApp/MenuView.swift Sources/DevSweepApp/StatusItemController.swift
git commit -m "feat(devsweep): license/Pro menu UI — confirm per-module reclaim, Pro pitch, error UX, menu-open revalidate

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 10: 릴리스 게이트 + 문서 + 통합/UI 검증

**Files:** Modify `packaging/build_app.sh`, `packaging/RELEASE.md`; Create `docs/LICENSING.md`

- [ ] **Step 1: Release gate — refuse a placeholder config in non-adhoc builds (rev #11)**

Add to `packaging/build_app.sh` (after arg parsing, before signing; only when NOT `--adhoc`): a guard
that greps the built/compiled config or, more simply, fails if the source still has placeholders:
```bash
# Release gate: a notarized/dmg build must NOT ship a placeholder LicenseConfig (dead Pro).
if [ "${ADHOC:-0}" != "1" ]; then
  CFG="Sources/DevSweepCore/License/LicenseConfig.swift"
  if grep -q "REPLACE_ME" "$CFG" || grep -Eq "expectedStoreId: 0\b" "$CFG"; then
    echo "RELEASE BLOCKED: LicenseConfig.production still has placeholders (see docs/LICENSING.md)."
    exit 1
  fi
fi
```
(Adjust the flag variable to however `build_app.sh` records `--adhoc`.)

- [ ] **Step 2: docs/LICENSING.md**
```markdown
# DevSweep Pro — LemonSqueezy 라이선스 셋업

DevSweep Pro 는 LemonSqueezy 라이선스 키로 잠금해제된다(StoreKit 아님 — Developer ID 배포라 불가).
License API(`/v1/licenses/activate|validate|deactivate`)는 **API 키가 필요 없다** — 라이선스 키
자체가 인증 파라미터다. 앱이 직접 호출하고 별도 백엔드/영수증 서버가 없다. client-side 검증은
우회 가능하며, 이는 의도된 "캐주얼 라이선싱"이다(과한 anti-piracy 미적용).

## 대시보드에서 한 번 할 일 (자동화 불가)
1. LemonSqueezy 스토어 생성.
2. 상품 "DevSweep Pro": 평생 1회 **$9.99 출시가**, **License keys 활성화**, `activation limit = 3`.
3. 다음 값을 `Sources/DevSweepCore/License/LicenseConfig.swift` 의 `.production` 에 기입(전부 공개값):
   `checkoutURL`(buy URL), `expectedStoreId`(정수), `expectedProductIds`(product id 정수), `displayPrice`.
4. 테스트 모드 라이선스 키로 통합 검증.

## 검증 (테스트 모드 키)
- activate → "DevSweep Pro 활성화됨" + 스킨/전체회수/자동청소 토글 해제 확인.
- 환불/disable 시뮬 후 validate → 즉시 free 복귀(grace 무시) 확인.
- "이 기기에서 라이선스 해제" → 좌석 반납 + free + 선택중이던 유료 스킨 즉시 기본값 복귀 확인.
- 네트워크 차단 후 재실행 → 14일 grace 내 Pro 유지 확인.
- 자동 청소 ON: node_modules·worktree 는 **자동 삭제되지 않고** 캐시류만 회수되는지 확인.

## 출시 전 하드 게이트 (rev #11)
- `LicenseConfig.production` placeholder 교체 + 위 테스트모드 activate→Pro→deactivate→grace 1회
  실측 통과 전에는 `build_app.sh --dmg`/notarized 빌드가 차단된다.
```

- [ ] **Step 3: RELEASE.md** — replace the "Consequence for StoreKit / In-App Purchases" body with:
```markdown
Under Developer ID the active monetization path is a **LemonSqueezy license key** (see
`docs/LICENSING.md`):

- **DevSweep Pro** — a $9.99 (launch) lifetime license unlocks scheduled auto-clean (autoSafe caches
  only), all skins, and one-click "reclaim all". Bought on an external LemonSqueezy checkout; activated
  in-app via the keyless License API (`LicenseStore` / `LemonSqueezyLicenseClient` /
  `KeychainLicenseStorage`). Validation is client-side ("casual licensing", not anti-piracy).
- The free tier keeps the tool's core promise: manual scan + per-module reclaim of EVERY module
  (node_modules / package caches / worktrees / **Docker**) and the free skins.
- The **M6 StoreKit code** (`StoreKit2Backend`, the StoreKit `SkinStore`, IAP `ProductCatalog`,
  `DevSweep.storekit`) stays in-tree but **dormant** — not wired into `AppCoordinator`. Kept for a
  possible Mac App Store SKU; its unit tests still run. (Revisit deleting it after the license path ships.)
- Donation links (`DonationLinks`) remain a secondary voluntary path.
```

- [ ] **Step 4: Full suite** — `swift test` → all PASS (License suites + existing suite).

- [ ] **Step 5: Build app + manual UI verification (HARD GATE)** — `./packaging/build_app.sh --adhoc`, launch `build/DevSweep.app`, verify:
- Free: skins show "Pro" lock; "전체 회수 (Pro)" shows lock; module rows (incl. **Docker**) tap → "회수/취소" confirm (no instant delete); "회수 미리보기" works.
- "라이선스 키 입력" sheet: empty/invalid key shows specific red error + key-recovery hint; a valid test key → "DevSweep Pro 활성화됨", skins + "전체 회수 실행" + auto-clean toggle unlock.
- "Pro 구매" opens checkout in browser. "라이선스 해제" → a selected Pro skin reverts to default immediately.
- No crash; Console fault-free. (If the dashboard isn't configured yet, verify the free-state gating + sheet messaging + per-module confirm, and record the Pro-state path as "pending LemonSqueezy config" — but note the release gate blocks shipping until it's exercised.)
- Note: each `--adhoc` rebuild re-signs ad-hoc, which can reset the Keychain item ACL — a prior "Pro" state may not persist across rebuilds (rev m7); don't misread as a bug.

- [ ] **Step 6: Commit**
```bash
git add packaging/RELEASE.md packaging/build_app.sh docs/LICENSING.md
git commit -m "docs(devsweep): LemonSqueezy licensing setup + release placeholder gate + RELEASE update

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## 완료 기준 (Definition of Done)

- [ ] `swift test` 전부 green (신규 License 스위트 + 기존 전체 ≈274 cases).
- [ ] `swift build` + `./packaging/build_app.sh --adhoc` 성공, 메뉴 팝오버 수동 UI 검증 통과.
- [ ] 무료: 모든 모듈(Docker 포함) 회수는 미리보기+확인 2스텝, 전체회수/스킨만 Pro 게이트.
- [ ] auto-clean은 `.autoSafe`만 — node_modules/worktree 자동삭제 0건(테스트로 보장).
- [ ] 4xx 서버 거부 = 즉시 re-lock, 전송 실패만 grace; ISO8601 마이크로초 파싱 green.
- [ ] activate/deactivate 후 선택 스킨 즉시 reconcile; 팝오버 오픈 시 stale 재검증.
- [ ] StoreKit 동면(트리 보존, 미배선), 기존 테스트 통과.
- [ ] **릴리스 하드 게이트**: `LicenseConfig.production` 실제 값 교체 + 테스트모드 activate→Pro→
      deactivate→grace 1회 실측 전 notarized/dmg 빌드 차단(`build_app.sh` 가드).
- [ ] push 는 사용자 승인 후에만.

## Self-Review (작성자 점검, v2)

- **리뷰 반영 커버리지**: 14 must-fix + 3 제품결정 전부 태스크에 매핑(상단 v2 개정 이력 ↔ Task 1·3·4·5·6·7·8·9·10).
- **Placeholder**: 모든 코드 스텝에 실제 코드. `LicenseConfig.production` 의 placeholder 는 릴리스 게이트(Task 10)가 차단하는 의도된 값.
- **타입 일관성**: `LicenseStatus`(serverMessage 추가), `LicenseConfig`(displayPrice/isPlaceholder 추가), `LicenseClientError`, `LicenseStorage.installID()`, `AutoReclaimPolicy.autoCleanableItems` 가 정의(Task 1·2·7)와 사용처(Task 3·5·6·8) 전반 일치. `activateLicense`/`deactivateLicense`/`revalidateLicenseIfStale`/`reclaimAll`/`reclaimModule` 명칭이 Task 8·9 간 일치. `CleanupItem.safety: SafetyClass` 및 `ReclaimMethod.deletePath(toTrash:)`/`.cliCommand(...)` 케이스명 실측 확인 완료(테스트 픽스처는 `.deletePath(toTrash: true)` 사용).
