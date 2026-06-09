# DevSweep Milestone 6 — StoreKit 수익화 / 스킨 IAP Implementation Plan

> **For agentic workers:** TDD for entitlement/unlock 로직(mock backend). 실제 StoreKit2는 컴파일+`.storekit` 로컬 설정. M1~M5 컨벤션. 작업 디렉토리 `DevSweep/`. push 금지.

**Goal:** RunCat식 수익화 — 모든 정리 기능 무료, 유료 스킨(IAP)으로 차별화 + 자발적 기부(외부 링크). 유료 스킨(dot-matrix/synthwave)을 구매/복원 시 잠금 해제.

**Architecture:** `PurchaseBackend` 프로토콜(M1~M4의 FileSystemDeleter/CommandRunner 추상화 패턴)로 StoreKit을 격리 → `StoreKit2Backend`(실제) + `MockPurchaseBackend`(테스트). 순수 `EntitlementResolver`(구매내역→해제 스킨 id 집합, TDD) + `SkinStore`(@MainActor, 구매·복원·해제상태 published). `DonationLinks`(외부 URL, 결제 로직 0). `DevSweep.storekit` 로컬 설정으로 Xcode/SKTest 검증. AppCoordinator.setSkin 게이트(유료는 entitled일 때만), MenuView에 구매/복원/기부.

**Tech Stack:** Swift 6.0 / StoreKit 2(Product/Transaction/Transaction.currentEntitlements) / Swift Testing. 외부 의존성 금지.

**Spec 근거:** `docs/superpowers/specs/2026-06-08-devsweep-design.md` §6(스킨 IAP 라인업·구매욕 장치·Apple 규정 분리·기부·아키텍처 영향).

**브랜치:** `design/devsweep-menubar-cleaner`. push 금지.

## ⚠️ Apple 규정 (코드/UI에 반영 — 리젝 회피)
- **스킨 = IAP만**(StoreKit). 외부 결제 우회 금지.
- **기부 = "보상 없는 순수 응원" 외부 링크만**. 앱 내 기부 버튼에 보상(전용 스킨 등) 문구 금지. 후원자 보상은 앱 밖(GitHub/웹)에서만.
- 유료 스킨은 OSS 마스코트 직접 차용 금지(장르 오마주 오리지널) — M5 절차적 스킨이라 해당 없음.

---

## File Structure (신규)
```
DevSweep/Sources/DevSweepCore/Store(IAP)/        # 순수 로직은 Core
├── ProductCatalog.swift       # product id 상수 + 메타(가격대/이름/포함 스킨), 단품·테마팩·All-Access
├── PurchaseBackend.swift      # 프로토콜: products()/purchase(id)/currentEntitlementIds()/restore()
├── EntitlementResolver.swift  # 순수: 보유 product id 집합 → 해제 skin id 집합(All-Access 포함규칙)
DevSweep/Sources/DevSweepApp/IAP/
├── StoreKit2Backend.swift     # 실제 StoreKit2 구현(Product.products/purchase/Transaction.currentEntitlements/finish)
├── SkinStore.swift            # @MainActor ObservableObject: 제품 로드·구매·복원·entitled skin 집합 published
├── DonationLinks.swift        # BuyMeACoffee/GitHubSponsors URL(보상 문구 금지), openURL
DevSweep/Tests/DevSweepCoreTests/
├── ProductCatalogTests.swift
├── EntitlementResolverTests.swift
└── SkinStoreTests.swift       # MockPurchaseBackend로 구매/복원/All-Access 해제 로직
DevSweep/Sources/DevSweepApp/Resources/DevSweep.storekit   # 로컬 StoreKit 설정(수동 검증용)
```
Package.swift: 필요 시 DevSweepApp 에 `.storekit` 리소스 처리(`resources: [.copy("Resources/DevSweep.storekit")]`). 그 외 변경 금지.

## 타입 계약
```swift
// 순수 (Core)
public struct IAPProduct: Sendable, Equatable {
    public let id: String          // "kr.qplace.devsweep.skin.dotmatrix" 등
    public let displayName: String
    public let kind: Kind          // .singleSkin(skinId) / .themePack([skinId]) / .allAccess / .seasonal([skinId])
    public enum Kind: Sendable, Equatable { case singleSkin(String); case themePack([String]); case allAccess; case seasonal([String]) }
}
public enum ProductCatalog {
    public static let all: [IAPProduct]      // dotmatrix($1.99)·synthwave($2.99) 단품, themepack, allAccess($9.99)
    public static let allAccessId: String
}
public protocol PurchaseBackend: Sendable {
    func loadProducts(ids: [String]) async throws -> [IAPProduct]
    func purchase(id: String) async throws -> Bool      // 성공(검증된 트랜잭션) 여부
    func currentEntitlementIds() async -> Set<String>   // 보유 product id
    func restore() async throws
}
public struct EntitlementResolver: Sendable {
    public init(catalog: [IAPProduct] = ProductCatalog.all)
    /// 보유 product id 집합 → 해제된 skin id 집합. allAccess 보유 시 카탈로그 전 스킨 해제.
    public func unlockedSkinIds(ownedProductIds: Set<String>) -> Set<String>
}
```
`SkinStore`(@MainActor): `@Published unlockedSkinIds`, `products`, `func load()`, `func buy(_ id)`, `func restorePurchases()`. backend 주입.
`StoreKit2Backend`: `Product.products(for:)`, `product.purchase()`(verification 체크 후 `transaction.finish()`), `Transaction.currentEntitlements` 순회, `AppStore.sync()`(restore). Transaction.updates 리스너로 외부 구매 반영.

## Tasks (TDD)
1. **ProductCatalog**(TDD: id/kind/allAccess 존재, 단가 메타). 커밋 `feat(devsweep): IAP ProductCatalog`.
2. **PurchaseBackend 프로토콜 + MockPurchaseBackend**(테스트 더블, 보유집합 주입·purchase 시 추가). 커밋 `feat(devsweep): PurchaseBackend protocol + mock`.
3. **EntitlementResolver**(TDD: 단품→해당 skin, allAccess→전체, themepack→복수, 미보유→무료스킨만/빈집합). 커밋 `feat(devsweep): EntitlementResolver (구매→스킨 해제)`.
4. **SkinStore**(@MainActor, MockPurchaseBackend로 TDD: load→products, buy→unlockedSkinIds 갱신, restore→복원, allAccess 구매 시 전체 해제). 커밋 `feat(devsweep): SkinStore (구매·복원·해제상태)`.
5. **StoreKit2Backend + DonationLinks**(실제 StoreKit2 — 컴파일 검증 위주; DonationLinks URL+openURL, 보상문구 0). 커밋 `feat(devsweep): StoreKit2 backend + donation links`.
6. **DevSweep.storekit 설정** + Package.swift 리소스. (product id/가격 카탈로그와 일치). 커밋 `feat(devsweep): local .storekit config`.
7. **통합**: AppCoordinator가 SkinStore 보유, `setSkin`이 유료 스킨은 `unlockedSkinIds`에 있을 때만 허용(아니면 무시/구매 유도). MenuView: 유료 스킨에 "Buy $X"/잠금, "Restore Purchases", 기부(BMC/Sponsors 외부 링크, 보상문구 없음). 커밋 `feat(devsweep): wire IAP into menu (buy/restore/donate gate)`.
8. 게이트: `swift test` 전체 green(160+신규) + `swift build` 경고 0 + `swift run DevSweepApp --render-samples /tmp/ds-x` 여전히 동작(회귀).

## 완료 신호
1. `M6_STOREKIT_DONE`
2. `swift test 2>&1 | tail -3`
3. `swift build 2>&1 | tail -1`
4. App Store Connect에 생성해야 할 **정확한 product id 목록 + 권장 가격**(카탈로그에서 추출) 출력
5. `git -C /Users/taejin/Documents/dev/gprecious-marketplace log --oneline -10`

## 비범위 (YAGNI / 수동·후속)
- App Store Connect 실제 상품 생성·가격 설정·앱 제출·공증·서명 = **사용자 수동(Apple 계정)** — 코드는 product id 상수로 준비, 단계는 문서화.
- 라이브 프리뷰(30초 임시적용 "Keep it $X") = 후속(전환 레버, 별도).
- 시즌 한정 드롭 운영, UGC 커스텀 등록 게이트 = 후속.
- 영수증 서버검증(StoreKit2 on-device 검증으로 충분).
