# DevSweep Milestone 4 — App Shell (메뉴바 + Watcher + Notifier + Reclaim 라우팅) Implementation Plan

> **For agentic workers:** TDD for pure logic (RED→GREEN→commit). GUI glue는 단위테스트 불가 → "컴파일 + `swift run` 기동 + NSStatusItem 생성" 이 수용 기준. M1~M3 컨벤션 준수. 작업 디렉토리 `DevSweep/`.

**Goal:** DevSweepCore(M1~M3) 위에 실제 메뉴바 상주 앱을 올린다. 회수 가능 용량을 메뉴바에 표시하고, 주기/디스크압박 스캔(Watcher), 임계 알림(Notifier), 승인 항목을 소유 모듈로 보내는 회수 라우팅을 갖춘다.

**Architecture:** 테스트 가능한 정책 코어(ScanTriggerPolicy / NotificationPolicy / ReclaimRouter / ScanCoordinator / DiskSpaceProbe)는 `DevSweepCore`에 두고 TDD. GUI/시스템 글루(NSStatusItem, SwiftUI 메뉴, NSBackgroundActivityScheduler, UNUserNotificationCenter)는 신규 **SwiftPM executable 타깃 `DevSweepApp`**. 앱은 `NSApp.setActivationPolicy(.accessory)`로 Dock 없이 메뉴바 전용(Info.plist 불요).

**Tech Stack:** Swift 6.0 / AppKit + SwiftUI / SPM executable / Swift Testing. 외부 의존성 추가 금지.

**Spec 근거:** `docs/superpowers/specs/2026-06-08-devsweep-design.md` §1(아키텍처/단일프로세스/SMAppService), §4(Watcher·Notifier), §5(인디케이터·메뉴), 컴포넌트 경계표.

**브랜치:** `design/devsweep-menubar-cleaner` (HEAD e6c4056, 83 tests green). push 금지.

---

## Execution Topology (herdr 3단계)

| Phase | 내용 | Worker | Effort |
|---|---|---|---|
| 1 Foundation | Package.swift executable 타깃 + 최소 기동 앱(NSStatusItem 정적) + DiskSpaceProbe 프로토콜 + AppConfig + ScanCoordinator | claude 단일 | ultracode |
| 2 Leaf 병렬 | A: ScanTriggerPolicy(+statfs DiskSpaceProbe) / B: NotificationPolicy / C: ReclaimRouter — 각자 worktree, 신규 파일만 | claude+codex | 기본 |
| 3 Integration | StatusItemController(라이브) + MenuView(SwiftUI) + AppCoordinator 배선 + WatcherService/NotifierService thin wrapper + 기동 스모크 | claude 단일 | ultracode |

leaf는 모두 `DevSweepCore/App/` 하위 **순수 로직 신규 파일**만 추가(Package.swift·executable 파일·서로 미수정). Foundation 커밋이 분기점.

---

## File Structure

신규 (DevSweepCore — 테스트 가능 코어):
```
DevSweep/Sources/DevSweepCore/App/
├── AppConfig.swift           # [F] 임계치/주기 설정값 (scanInterval, diskPressurePct, notifyThresholdBytes, gauge 5/20GB)
├── DiskSpaceProbe.swift      # [F] 프로토콜: free/total bytes
├── ScanCoordinator.swift     # [F] registry.scanGrouped()→ScanRecord→store.recordScan, 최신 reclaimable 반환
├── ScanTriggerPolicy.swift   # [A] 순수: 언제 스캔? (interval 경과 | 디스크압박 | 수동) + 이유
├── StatfsDiskSpaceProbe.swift# [A] statvfs 기반 실제 구현
├── NotificationPolicy.swift  # [B] 순수: 알릴까? (밴드 전이 + 하루 1회 스로틀)
└── ReclaimRouter.swift       # [C] 승인 [CleanupItem] → 소유 모듈 reclaim + audit 기록
```
신규 (DevSweepApp — executable, GUI 글루):
```
DevSweep/Sources/DevSweepApp/
├── main.swift                # [F] NSApplication.accessory 기동 + AppDelegate
├── AppDelegate.swift         # [F→I] applicationDidFinishLaunching: setActivationPolicy(.accessory), StatusItemController 생성
├── StatusItemController.swift # [I] NSStatusItem + 메뉴 호스팅 (NSHostingView/NSMenu)
├── MenuView.swift            # [I] SwiftUI: 회수 가능 총량 + topModules + "지금 스캔" + 리뷰/승인 + 설정/기부 placeholder
├── AppCoordinator.swift      # [I] DetectorRegistry+Store+정책들+Watcher+Notifier 배선, ObservableObject
├── WatcherService.swift      # [I] NSBackgroundActivityScheduler + DiskSpaceProbe → ScanTriggerPolicy thin
└── NotifierService.swift     # [I] UNUserNotificationCenter + NotificationPolicy thin
```
신규 테스트:
```
DevSweep/Tests/DevSweepCoreTests/
├── AppConfigTests.swift, ScanCoordinatorTests.swift   # [F]
├── ScanTriggerPolicyTests.swift                        # [A]
├── NotificationPolicyTests.swift                       # [B]
└── ReclaimRouterTests.swift                            # [C]
```
`Package.swift`: executable 타깃 추가
```swift
.executableTarget(name: "DevSweepApp", dependencies: ["DevSweepCore"])
```
(DevSweepCore 타깃/테스트 타깃은 그대로. sqlite3 linkerSettings 유지.)

---

## 타입 계약 (정확히)

```swift
// [F] AppConfig
public struct AppConfig: Sendable, Equatable {
    public var scanInterval: TimeInterval      // 기본 6*3600
    public var diskPressurePct: Double         // 기본 0.15 (15% 미만 free → 압박)
    public var notifyThresholdBytes: Int64     // 기본 20 * 1_000_000_000
    public var gaugeLowBytes: Int64            // 5GB
    public var gaugeHighBytes: Int64           // 20GB
    public init(...все with defaults...)
    public static let `default` = AppConfig()
}

// [F] DiskSpaceProbe
public protocol DiskSpaceProbe: Sendable {
    func snapshot() -> (freeBytes: Int64, totalBytes: Int64)
}

// [F] ScanCoordinator — registry 스캔을 ScanRecord로 영속 + reclaimable 합 반환
public struct ScanCoordinator: Sendable {
    public init(registry: DetectorRegistry, store: any Store, idProvider: @escaping @Sendable () -> String, now: @escaping @Sendable () -> Date)
    public func runScan() async -> ScanRecord   // scanGrouped→ScanRecord(StoreBuilders)→store.recordScan→반환
}

// [A] ScanTriggerPolicy — 순수
public enum ScanTrigger: Sendable, Equatable { case interval, diskPressure, manual, none }
public struct ScanTriggerPolicy: Sendable {
    public init(config: AppConfig)
    /// lastScan(없으면 nil), now, disk snapshot, manualRequested 로 트리거 판정.
    public func evaluate(lastScan: Date?, now: Date, disk: (freeBytes: Int64, totalBytes: Int64), manualRequested: Bool) -> ScanTrigger
}
// 규칙: manualRequested→.manual; free/total < diskPressurePct → .diskPressure;
//       lastScan==nil 또는 now-lastScan >= scanInterval → .interval; else .none. (우선순위 manual>pressure>interval)

// [B] NotificationPolicy — 순수
public struct NotificationDecision: Sendable, Equatable { public let shouldNotify: Bool; public let band: Int }
public struct NotificationPolicy: Sendable {
    public init(config: AppConfig)
    /// reclaimableBytes 밴드(0:<low,1:low~high,2:>=notifyThreshold). lastNotifiedBand/lastNotifiedAt 대비
    /// 상위 밴드로 전이 && (하루 1회 스로틀: now-lastNotifiedAt>=24h 또는 밴드 상승) 일 때만 notify.
    public func evaluate(reclaimableBytes: Int64, lastNotifiedBand: Int, lastNotifiedAt: Date?, now: Date) -> NotificationDecision
}

// [C] ReclaimRouter — 승인 항목을 소유 모듈로
public struct ReclaimRouter: Sendable {
    public init(modules: [any CleanupModule], store: any Store, now: @escaping @Sendable () -> Date)
    /// item.id 의 "<moduleId>:" 접두 또는 module.scan 매칭으로 소유 모듈 결정 → 각 모듈 reclaim(dryRun) →
    /// 결과 합치고 store.recordAudit(StoreBuilders.auditRecords) 기록 → outcomes 반환.
    public func reclaim(_ items: [CleanupItem], dryRun: Bool) async -> [ReclaimOutcome]
}
// 매칭: itemId.split(":").first == module.id. 모듈 못 찾으면 .failed("no owning module").
```

---

## Tasks

### Phase 1 — Foundation (claude ultracode)

1. **Package.swift executable 타깃 추가** → `swift build` 통과(빈 main 먼저). 커밋 `chore(devsweep): add DevSweepApp executable target`.
2. **AppConfig** (TDD: 기본값/Equatable). 커밋 `feat(devsweep): AppConfig`.
3. **DiskSpaceProbe 프로토콜 + Mock**(테스트 더블, 고정 free/total). 커밋 `feat(devsweep): DiskSpaceProbe protocol + mock`.
4. **ScanCoordinator** (TDD: mock DetectorRegistry는 불가 → 실제 DetectorRegistry + MockCleanupModule로 구성, InMemoryStore 주입 → runScan 후 store.latestScan == 반환 ScanRecord, perModule 합 일치). 커밋 `feat(devsweep): ScanCoordinator (scan→record→persist)`.
5. **최소 기동 앱**: `main.swift`(NSApplication, delegate 설정, `.accessory`) + `AppDelegate`(applicationDidFinishLaunching에서 NSStatusItem 생성, button.title="◌" 임시) → `swift run DevSweepApp` 가 크래시 없이 기동(수동), `swift build` 통과. 커밋 `feat(devsweep): minimal accessory menubar app (static status item)`.
6. Foundation 게이트: `swift test` 전체 green + `swift build` 경고 0.

### Phase 2 — Leaf 병렬 (worktree)

- **A (claude)**: ScanTriggerPolicy(TDD: manual/pressure/interval/none 우선순위·경계) + StatfsDiskSpaceProbe(statvfs 실측, 통합 가벼운 sanity 1개). 커밋 `feat(devsweep): ScanTriggerPolicy + statfs probe`.
- **B (codex)**: NotificationPolicy(TDD: 밴드 전이/하루 스로틀/하강 시 미알림/동일밴드 24h 경계). 커밋 `feat(devsweep): NotificationPolicy (밴드+스로틀)`.
- **C (claude)**: ReclaimRouter(TDD: MockCleanupModule 2개+InMemoryStore → itemId 접두로 라우팅, dryRun 시 deleter 미호출, audit 기록 건수/상태, 미소유 항목 .failed). 커밋 `feat(devsweep): ReclaimRouter (모듈 라우팅 + audit)`.

각 leaf: `DevSweepCore/App/` 하위 신규 파일 + 대응 테스트 파일만. Package.swift·서로·foundation 파일 미수정.

### Phase 3 — Integration (claude ultracode, leaf 머지 후)

7. **WatcherService**: NSBackgroundActivityScheduler 주기 + 수동 트리거 → DiskSpaceProbe 스냅샷 → ScanTriggerPolicy.evaluate → 트리거면 콜백. (thin; 컴파일 + 기동)
8. **NotifierService**: UNUserNotificationCenter 권한요청 + NotificationPolicy 통과 시 알림(액션: 리뷰/안전캐시정리/오늘그만). (thin)
9. **AppCoordinator (ObservableObject)**: DefaultDetectorRegistry + SQLiteStore(앱 지원 디렉토리 경로) + ScanCoordinator + ScanTriggerPolicy + NotificationPolicy + ReclaimRouter + WatcherService + NotifierService 배선. `reclaimableBytes`/`topModules`/`lastScan` @Published. "지금 스캔"/"승인 회수" 액션.
10. **StatusItemController + MenuView(SwiftUI)**: NSStatusItem button 이미지/타이틀에 회수 가능 총량 표시(임계 5/20GB 색·강조), 클릭 시 MenuView 팝오버(총량·topModules·지금스캔·리뷰/승인·설정·기부 외부링크 placeholder).
11. **AppDelegate 배선**: AppCoordinator 생성·StatusItemController 연결·Watcher 시작.
12. **게이트**: `swift test` 전체 green + `swift build` 경고 0. `swift run DevSweepApp` 기동(백그라운드) → 5초 후 프로세스 생존 확인 → 종료. 커밋들 분할.

---

## 완료 신호 (각 워커)
- Foundation: `M4_FOUNDATION_DONE` + `swift test` tail + git log.
- 각 leaf: `M4_LEAF_<X>_DONE` + 해당 `swift test --filter` + git log -2.
- Integration: `M4_INTEGRATION_DONE` + `swift build 2>&1|tail -3` + `swift test 2>&1|tail -3` + `swift run DevSweepApp & sleep 5; kill %1` 결과 + git log -10.

## 비범위 (YAGNI)
- 스킨 렌더링(M5) — M4 인디케이터는 기본 텍스트/단색 게이지로 최소.
- StoreKit/기부 실로직(M6) — 메뉴엔 placeholder 항목만.
- SMAppService 로그인 자동시작 — 설정 토글 자리만, 실연동 후속.
- FSEvents 실시간 감시(설계상 비채택).
