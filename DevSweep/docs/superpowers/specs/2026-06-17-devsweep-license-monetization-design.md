# DevSweep 수익화 설계 — LemonSqueezy 라이선스 키

- **상태**: 승인됨 (브레인스토밍 완료, 구현 계획 대기)
- **날짜**: 2026-06-17
- **대상 앱**: DevSweep (macOS 메뉴바, Developer ID 직접배포)

## 1. 배경과 제약

DevSweep는 디스크 전역(Docker CLI, `~/.npm`/`~/.gradle` 등 전역 캐시, 임의 경로의
`node_modules`)을 스캔·회수한다. 이는 **비샌드박스 + Full Disk Access**를 요구하므로
배포 모델이 **Developer ID 직접배포(DMG/Homebrew)로 강제**된다(Mac App Store는 샌드박스 필수).

결과적으로 **StoreKit IAP는 사용 불가**다. 트리에 완성되어 있는 M6 StoreKit 코드
(`StoreKit2Backend`, StoreKit판 `SkinStore`, IAP `ProductCatalog`, `DevSweep.storekit`)는
Developer ID 빌드에서 `Product.products(for:)`가 빈 배열을 반환하여 **동면 상태**다.
현재 실질 수익화는 자발적 기부(`DonationLinks`) 뿐이다.

`packaging/RELEASE.md`가 이미 답을 명시했다: *유료 잠금해제가 필요하면 non-StoreKit
메커니즘(Paddle / LemonSqueezy / Gumroad + 라이선스 키)이 필요 — 별도 결정.* 본 문서가 그 결정이다.

### 핵심 결정 (확정)

| 결정 | 선택 | 근거 |
|---|---|---|
| 결제 메커니즘 | 외부 체크아웃 + 라이선스 키 | StoreKit 불가, Developer ID 유지 |
| 결제 제공자 | **LemonSqueezy** | Merchant of Record(세금 대리) + 클라이언트용 License API |
| 판매 형태 | 단일 **DevSweep Pro** | 스킨+자동화 묶음. 4-상품 카탈로그보다 단순 |
| 과금 | **평생 1회 $19.99** | 인디 디스크 도구엔 평생 1회가 거부감 적고 운영 단순 |
| 무료/Pro 경계 | 도구 본질=무료, 일괄/자동화/스킨=Pro | 무료 가치 훼손 없이 실질 수익화 |

### 검증된 가정 (LemonSqueezy License API)

- `activate`/`validate`/`deactivate`는 **API 키 불필요** — 라이선스 키 자체가 인증 파라미터.
  → 앱이 직접 호출 가능, **별도 백엔드 서버·영수증 서버 불필요**.
- `validate` 응답의 `meta.store_id` / `meta.product_id`로 "내 Pro 상품에서 발급된 키"임을 바인딩 검증.
- `license_key.status`(active/inactive/expired/disabled) + `valid` 불리언으로 환불 시 자동 재잠금.
- `activation_limit`/`activation_usage`로 좌석(기기) 한도 관리. 호출은 분당 60회 제한.
- 베이스 URL `https://api.lemonsqueezy.com/v1/licenses/*`, `Accept: application/json`,
  `Content-Type: application/x-www-form-urlencoded`.

## 2. 아키텍처

StoreKit의 `purchase(id:)→Bool`(인앱 시트 동기 완료) 모델은 라이선스 흐름(외부 체크아웃 →
이메일로 키 수령 → 앱에 키 입력 → 활성화)과 형태가 다르다. 따라서 기존 `PurchaseBackend`에
끼워맞추지 않고 **전용 추상화를 신설**한다. 순수·테스트된 `EntitlementResolver`는 재사용한다.

### 신규 파일

```
Sources/DevSweepCore/License/
  LicenseActivating.swift    # protocol: activate / validate / deactivate
  LicenseModels.swift        # LicenseStatus, LicenseEntitlement(.free/.pro), ActivationResult
  LicenseBinding.swift       # validate 응답 → 엔타이틀먼트. store/product 일치 + status/valid 검증 (순수)
  LicenseStore.swift         # @MainActor ObservableObject 상태머신 (SkinStore 대응물)
  LicenseConfig.swift        # 체크아웃 URL, expected storeId/productId, API base, grace window (전부 공개값)
  LicenseStorage.swift       # protocol: 키+instanceId 영속화 (Core는 추상화만)

Sources/DevSweepApp/License/
  LemonSqueezyLicenseClient.swift  # LicenseActivating 실제 구현 (URLSession → api.lemonsqueezy.com)
  KeychainLicenseStorage.swift     # LicenseStorage 실제 구현 (Keychain Services)

Tests/DevSweepCoreTests/
  LicenseBindingTests.swift
  LicenseStoreTests.swift          # MockLicenseClient + MockLicenseStorage 구동
```

### `LicenseActivating` (Core 프로토콜)

```swift
public protocol LicenseActivating: Sendable {
    /// 키 활성화 → instanceId 발급. 좌석 초과/잘못된 키는 실패로 보고.
    func activate(key: String, instanceName: String) async throws -> ActivationResult
    /// 키+instanceId 검증 → 현재 LicenseStatus(원본 meta 포함).
    func validate(key: String, instanceId: String) async throws -> LicenseStatus
    /// 이 기기에서 해제(좌석 반납).
    func deactivate(key: String, instanceId: String) async throws
}
```

`ActivationResult`/`LicenseStatus`는 StoreKit 의존이 없는 순수 값 타입(테스트 가능).
`LicenseStatus`는 `valid: Bool`, `status: String`, `storeId/productId`, `expiresAt`, `activationLimit/Usage`를 담는다.

### `LicenseBinding` (Core, 순수)

`LicenseStatus` + `LicenseConfig` → `LicenseEntitlement`:
- `valid == true` **그리고** `status == "active"` **그리고** `storeId == config.expectedStoreId`
  **그리고** `productId ∈ config.expectedProductIds` → `.pro`
- 그 외(환불·폐기·만료·타 상품 키) → `.free`

이 한 곳에 "Pro 자격" 규칙을 모은다(테스트 집중).

### `LicenseStore` (Core, `@MainActor ObservableObject`)

`SkinStore`와 동일한 역할의 상태 머신. StoreKit/AppKit import 없음.

```swift
@Published private(set) var entitlement: LicenseEntitlement   // .free / .pro
@Published private(set) var unlockedSkinIds: Set<String>      // Pro → EntitlementResolver(.allAccess) 전 스킨
@Published private(set) var activationState: ActivationState  // .idle/.activating/.validating/.invalid(reason)

func activate(key:) async        // client.activate → storage 저장 → validate → entitlement 갱신
func validate() async            // 실행 시/주기적. 성공 시 lastValidatedAt 갱신
func deactivate() async          // client.deactivate → storage 삭제 → .free
func openCheckout()              // config.checkoutURL 외부 브라우저 오픈
func canSelect(_ skin:) -> Bool  // skin.isFree || unlockedSkinIds.contains(id)
var isPro: Bool { entitlement == .pro }
```

**오프라인 유예**: `validate()`가 네트워크 오류로 실패하면 저장된 `lastValidatedAt`를 보고
`now - lastValidatedAt < graceWindow`(제안 14일)인 동안 직전 Pro 상태를 유지한다.
키가 명시적으로 무효(`valid:false`)로 응답되면 유예 없이 즉시 `.free`.

### `LicenseStorage` / `KeychainLicenseStorage`

라이선스 키 + instanceId는 **자격증명**이므로 UserDefaults가 아닌 **Keychain**에 저장.
Core는 `LicenseStorage` 프로토콜만 두고, 실제 Keychain 구현은 App에 둔다(테스트는 in-memory mock).

### 동면 처리 (삭제 금지)

`StoreKit2Backend`, StoreKit판 `SkinStore`, IAP `ProductCatalog`, `DevSweep.storekit`,
`PurchaseBackend`/`EntitlementResolver`(EntitlementResolver는 재사용) 는 **트리에 보존**한다.
프로젝트 규칙(함부로 삭제 금지) + RELEASE.md의 App Store 피벗 보존 의도. 기존 205개 테스트는
동면 코드(MockPurchaseBackend 구동)라 그대로 통과한다. `AppCoordinator`는 `StoreKit2Backend()`
주입과 `observeTransactionUpdates`를 `LicenseStore` 배선으로 교체한다.

## 3. 무료 / Pro 경계선 (승인됨)

| 기능 | 무료 | Pro |
|---|:---:|:---:|
| 수동 "지금 스캔" + 회수가능 총량/상위 모듈/히스토리 | ✅ | ✅ |
| 드라이런 미리보기 | ✅ | ✅ |
| 모듈별 수동 회수(node_modules·패키지 캐시·worktree 하나씩) | ✅ | ✅ |
| 자동 스캔(메뉴바 게이지 최신화) | ✅ | ✅ |
| 무료 스킨(배터리·게이지) | ✅ | ✅ |
| 알림 | ✅ | ✅ |
| **원클릭 "전체 회수"** | — | ✅ |
| **예약/자동 청소**(hands-off 자동 reclaim) | — | ✅ |
| **Docker prune**(고위험·고급) | — | ✅ |
| **전 스킨**(도트매트릭스·신스웨이브·향후 전부) | — | ✅ |

원칙: 무료로도 *모듈별로* 전부 정리 가능(도구 본질 보존). Pro = "한 방에 + 알아서 + 꾸미기".

### 게이팅 구현 노트

- **전체 회수(Pro)**: 현재 `MenuView`의 단일 "승인 회수 실행" 버튼이 `currentItems` 전체를
  한 번에 회수한다 → 이를 Pro 게이트. 무료는 **모듈 행 탭 → 해당 모듈만 회수**(신규 UI).
  `reclaimRouter.reclaim(grouped:)`와 `currentGrouped`가 이미 모듈별 회수를 지원하므로 라우팅 재사용.
- **예약/자동 청소(Pro)**: 현재 `WatcherService`는 자동 **스캔**만 한다(`scanNow` 호출). 자동
  **회수**는 미구현이다 → Pro에서 "스캔 후 자동 reclaim" 경로를 신설하고 `isPro`로 게이트.
  자동 스캔 자체는 무료 유지(게이지 최신화는 메뉴바의 본질).
- **Docker prune(Pro)**: `DockerModule`의 회수 경로를 `isPro`로 게이트(무료는 Docker 회수가능량을
  보여주되 회수는 Pro 유도). 다른 모듈의 모듈별 회수는 무료.
- **스킨(Pro)**: `LicenseStore.canSelect`가 `SkinStore.canSelect`를 대체. Pro → 전 스킨.

## 4. 가격 (승인됨)

**평생 1회 결제 $19.99.** 구독 아님. 출시 할인($14.99)은 LemonSqueezy 대시보드 + 표시 문구만
바꾸면 되는 값이라 추후 자유. 메뉴의 "Pro 구매" 버튼은 체크아웃 URL을 열며, 가격은 체크아웃
페이지에 표시된다(앱 내 표시 가격은 단순 문자열).

## 5. UX 변경 (MenuView)

- **스킨 영역**: 개별 "Buy $X" 버튼 제거 → 잠긴 스킨에 자물쇠 + "Pro" 라벨. Pro면 전 스킨 선택 가능.
- **Pro 영역(신규)**: Pro 미보유 시 `[DevSweep Pro 구매]` + `[라이선스 키 입력]` 행. 보유 시
  "Pro 활성화됨" 배지 + `[이 기기에서 해제]`(deactivate) 링크.
- **라이선스 키 입력 시트**: 텍스트필드 + 활성화 버튼 + 상태(activating/성공/실패 사유).
- **게이트 액션**: "전체 회수"·"자동 청소"·"Docker prune"에 자물쇠 + "Pro", 탭 시 구매 유도.
- **푸터**: "모든 정리 기능은 계속 무료입니다"(App Store 기부 컴플라이언스 문구) 제거 — Developer
  ID라 불필요. "핵심 정리는 무료 · Pro로 일괄/자동화/스킨" 으로 재구성. 기부 링크는 유지(축소).

## 6. 사용자가 직접 할 일 (자동화 불가)

RELEASE.md의 Apple 자격증명 설정과 동일 성격. LemonSqueezy 대시보드에서:

1. 스토어 생성.
2. "DevSweep Pro" 상품 생성 — 평생(one-time), **License keys 활성화**, `activation_limit = 3`.
3. 체크아웃 URL + `store_id` + `product_id` 확보 → `LicenseConfig`에 기입(전부 공개값, 비밀 아님).
4. 테스트 모드 라이선스 키로 앱 통합 검증(활성화→Pro→해제→free).

## 7. 테스트 전략

- **단위(Core)**: `LicenseBinding`(active→pro, 환불/폐기/만료→free, 타 store/product 키 거부),
  `LicenseStore` 상태 머신(활성화 성공/실패, 좌석 초과, 오프라인 유예 유지/만료, deactivate→free),
  `LicenseStorage` 라운드트립(in-memory mock).
- **회귀**: 기존 205개 테스트(동면 StoreKit 경로) 그대로 통과 확인.
- **통합(수동)**: LemonSqueezy 테스트 모드 키로 실제 activate/validate/deactivate 1회 검증.
- **UI 검증(HARD GATE)**: 빌드 후 메뉴바 팝오버를 실제로 열어 무료 상태(게이트 자물쇠) /
  키 입력 / Pro 상태 전환을 클릭 확인.

## 8. 범위 밖 (YAGNI)

구독, 인앱 임베디드 체크아웃(Lemon.js 오버레이/webview), 무료체험·기간제한, 다중 티어,
자체 webhook 수신 서버, 영수증 서버, 가족 공유.

## 9. 영향받는 기존 파일 (요약)

- `Sources/DevSweepApp/AppCoordinator.swift` — StoreKit 주입 → LicenseStore 배선, `isPro` 게이트,
  자동 reclaim 경로(Pro).
- `Sources/DevSweepApp/MenuView.swift` — 스킨/Pro/라이선스 UI, 모듈별 회수, 게이트 라벨, 푸터.
- `Sources/DevSweepApp/WatcherService.swift` (또는 호출부) — 자동 reclaim 트리거(Pro).
- `packaging/RELEASE.md` — 수익화 경로를 LemonSqueezy 라이선스로 갱신(StoreKit 동면 명시 유지).
- `docs/` — LemonSqueezy 대시보드 셋업 절차 문서화.
