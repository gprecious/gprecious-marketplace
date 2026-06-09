# DevSweep Milestone 3 — Store / SQLite / Trends Implementation Plan

> **For agentic workers:** TDD (RED→GREEN→commit). Steps use checkbox tracking. Follow M1/M2 conventions exactly (Swift Testing `import Testing`/`@Test`/`#expect`, `actor` for mutable doubles, `TempDir` for fs fixtures). 작업 디렉토리는 `DevSweep/`.

**Goal:** 스캔 히스토리 + 회수 감사 로그를 영속화하고 추세를 계산하는 Store 계층을 `DevSweepCore`에 추가한다. M5 인디케이터(추세 표시)와 "뭐가 지워졌지?" 감사의 데이터 기반.

**Architecture:** `Store` 프로토콜(append-only 히스토리) — `InMemoryStore`(actor, 기본·테스트) + `SQLiteStore`(actor, `import SQLite3` 파일 영속). 순수 `TrendCalculator`로 추세 계산. `DetectorRegistry.scanGrouped()` 결과 → `ScanRecord`, `[ReclaimOutcome]` → `[AuditRecord]` 빌더.

**Tech Stack:** Swift 6.0 / SPM / Swift Testing. SQLite는 시스템 `import SQLite3`(외부 의존성 없음) — `Package.swift`의 DevSweepCore 타깃에 `linkerSettings: [.linkedLibrary("sqlite3")]` 추가.

**Spec 근거:** `docs/superpowers/specs/2026-06-08-devsweep-design.md` §1(Store), §3-④(감사 로그).

**브랜치:** `design/devsweep-menubar-cleaner` (현재 HEAD 9ff964a, M1+M2 완료, 66 tests green). push 금지.

---

## File Structure (신규)

```
DevSweep/Sources/DevSweepCore/Store/
├── ScanRecord.swift        # 한 번의 스캔 스냅샷 (timestamp + module별 reclaimable + total)
├── AuditRecord.swift       # 한 reclaim 결과의 감사 항목
├── Store.swift             # 프로토콜 (append-only)
├── InMemoryStore.swift     # actor, 기본/테스트 구현
├── SQLiteStore.swift       # actor, import SQLite3 파일 영속
├── TrendCalculator.swift   # 순수 추세 계산
└── StoreBuilders.swift     # scanGrouped()→ScanRecord, [ReclaimOutcome]→[AuditRecord]
DevSweep/Tests/DevSweepCoreTests/
├── StoreModelsTests.swift
├── InMemoryStoreTests.swift
├── SQLiteStoreTests.swift
├── TrendCalculatorTests.swift
└── StoreBuildersTests.swift
```

`Package.swift` 수정: DevSweepCore 타깃에 `linkerSettings: [.linkedLibrary("sqlite3")]` 만 추가 (다른 변경 금지).

---

## 타입 계약 (정확히 따를 것)

```swift
import Foundation

/// 한 번의 스캔 스냅샷. timestamp 주입형(테스트 결정성). totalBytes는 perModule 합과 일치.
public struct ScanRecord: Sendable, Equatable, Identifiable {
    public let id: String                 // 호출자 주입 (UUID 또는 "scan-<n>"); 영속 PK
    public let timestamp: Date
    public let perModule: [String: Int64] // module id → reclaimable bytes
    public let totalBytes: Int64          // == perModule.values.reduce(0,+)
    public init(id: String, timestamp: Date, perModule: [String: Int64]) {
        self.id = id; self.timestamp = timestamp; self.perModule = perModule
        self.totalBytes = perModule.values.reduce(0, +)
    }
}

/// 한 reclaim 결과의 감사 항목.
public struct AuditRecord: Sendable, Equatable {
    public let timestamp: Date
    public let itemId: String
    public let moduleId: String?
    public let method: String             // "deletePath(trash:false)" / "cliCommand(docker builder prune -f)"
    public let bytesReclaimed: Int64      // deleted면 실제, dryRun이면 계획치, 그 외 0
    public let status: String             // "deleted"/"dryRun"/"skippedProtected"/"failed"
    public init(timestamp: Date, itemId: String, moduleId: String?, method: String, bytesReclaimed: Int64, status: String) { ... }
}

/// Append-only 영속 계층. 삭제 로직 없음.
public protocol Store: Sendable {
    func recordScan(_ record: ScanRecord) async
    func recordAudit(_ records: [AuditRecord]) async
    func recentScans(limit: Int) async -> [ScanRecord]   // 최신순(timestamp desc)
    func auditLog(limit: Int) async -> [AuditRecord]      // 최신순
    func latestScan() async -> ScanRecord?
}
```

`InMemoryStore`: `actor`, 배열 누적, 조회 시 timestamp desc 정렬 + limit.
`SQLiteStore`: `actor`. `init(path: String) throws` — sqlite3_open, 테이블 2개 생성(`scans(id TEXT PRIMARY KEY, ts REAL, total INTEGER, per_module TEXT)` — per_module은 JSON 문자열; `audits(ts REAL, item_id TEXT, module_id TEXT, method TEXT, bytes INTEGER, status TEXT)`). prepared statement로 insert/select. 같은 path로 새 인스턴스 열면 데이터 유지.

`TrendCalculator`(순수 struct):
- `currentTotal(_ scans: [ScanRecord]) -> Int64` — 최신 스캔 total (없으면 0)
- `delta(_ scans: [ScanRecord], since: Date) -> Int64` — 최신 total − (since 이전 가장 최근 스캔 total)
- `topModules(_ scan: ScanRecord, limit: Int) -> [(module: String, bytes: Int64)]` — bytes desc 정렬
- `isGrowing(_ scans: [ScanRecord]) -> Bool` — 최근 2개 스캔 total 증가 여부

`StoreBuilders`(static/free funcs):
- `ScanRecord(id:timestamp:from grouped: [(module: String, items: [CleanupItem])])` — perModule = 각 module별 items.sizeBytes 합.
- `auditRecords(timestamp:from outcomes: [ReclaimOutcome]) -> [AuditRecord]` — ReclaimStatus → (status 문자열, bytes) 매핑: `.deleted(b)`→("deleted",b), `.dryRun(b)`→("dryRun",b), `.skippedProtected`→("skippedProtected",0), `.failed`→("failed",0). method는 `item.reclaimMethod` 설명 문자열, moduleId는 itemId의 `"<module>:..."` 접두 또는 nil.

---

## Tasks (TDD, 각 Task = 실패테스트→실패확인→구현→통과→커밋)

### Task 1: Package.swift sqlite3 링크
- `.target(name: "DevSweepCore", linkerSettings: [.linkedLibrary("sqlite3")])` 로 수정. `cd DevSweep && swift build` 통과 확인. 커밋 `chore(devsweep): link system sqlite3 for Store`.

### Task 2: ScanRecord + AuditRecord 모델
- 테스트: totalBytes == perModule 합; Equatable. 구현 후 커밋 `feat(devsweep): Store 모델 (ScanRecord/AuditRecord)`.

### Task 3: Store 프로토콜 + InMemoryStore
- 테스트(actor): recordScan×3 → recentScans(limit:2) 최신 2개 timestamp desc; latestScan 최신; recordAudit + auditLog 최신순/limit. 커밋 `feat(devsweep): Store 프로토콜 + InMemoryStore`.

### Task 4: TrendCalculator
- 테스트: 알려진 시리즈 → currentTotal, delta(since), topModules desc, isGrowing(증가/감소/단일/빈). 커밋 `feat(devsweep): TrendCalculator (추세 계산)`.

### Task 5: StoreBuilders
- 테스트: scanGrouped 모의 → ScanRecord perModule 합 정확; [ReclaimOutcome] 4종 status → AuditRecord 매핑(deleted/dryRun/skippedProtected/failed bytes·status). 커밋 `feat(devsweep): StoreBuilders (scan/outcome → record)`.

### Task 6: SQLiteStore (영속 통합)
- 테스트(TempDir db 경로): recordScan+recordAudit → recentScans/auditLog 일치; **같은 path로 새 SQLiteStore 인스턴스 열면 데이터 유지**(영속 검증); limit/정렬. 커밋 `feat(devsweep): SQLiteStore (sqlite3 파일 영속)`.

### Task 7: 전체 게이트
- `cd DevSweep && swift test` 전체 green(M1+M2 66 + M3 신규). `swift build` 경고 0. M1 pyiri 회귀 보존 확인.

---

## 완료 신호 (워커 출력)
1. `M3_STORE_DONE`
2. `cd /Users/taejin/Documents/dev/gprecious-marketplace/DevSweep && swift test 2>&1 | tail -3`
3. `git -C /Users/taejin/Documents/dev/gprecious-marketplace log --oneline -8`

## 비범위 (YAGNI)
증분 du 캐싱(별도)·UI 바인딩(M4/M5)·감사로그 보존정책(후속).
