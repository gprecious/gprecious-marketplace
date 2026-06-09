# DevSweep Milestone 2 — Detector 모듈 설계

- 작성일: 2026-06-09
- 상태: 설계 승인 완료 → 구현 계획(writing-plans) 대기
- 상위 설계: `docs/superpowers/specs/2026-06-08-devsweep-design.md` (§2 Detector 모듈, §3 Safety Layer)
- 선행: Milestone 1 (Safety Layer) 완료 — `design/devsweep-menubar-cleaner` 브랜치, 33 테스트 green

## 목표

개발 도구가 자동 증식시키는 캐시·산출물을 탐지하는 Detector 모듈 계층을 M1 안전 핵심 위에 얹는다. 세 계열(Docker / 패키지 캐시 / node_modules) 디텍터 + 모듈을 병렬 실행·집계하는 레지스트리 + CLI 기반 회수(prune) 경로. 2026-06-06 수동 정리로 회수한 ~51GB가 전부 이 세 계열이었다 — M2는 그것을 엔진으로 재현한다.

## M1에서 이미 구현된 것 (M2가 의존·재사용)

- `CleanupItem`(id, path?, sizeBytes, lastUsed?, var safety, reclaimMethod), `SafetyClass`(.autoSafe/.reviewNeeded/.protected), `ReclaimMethod`(.deletePath(toTrash:)/.cliCommand(executable:arguments:))
- `SafetyLayer.evaluate(_:)` — 3-gate(protected-registry → active-check signals → classification). 활성검사 신호: process/launchd/crontab/recent-use/**parent-project**
- `Reclaimer.reclaim(_:dryRun:)` — deletePath 항목을 SafetyLayer 경유로 회수. **dry-run은 deleter 미호출, protected는 skip** 불변식 보유. cliCommand는 현재 미구현 placeholder
- `CommandRunner.run(_:_:) -> String`(stdout-only), `ProcessCommandRunner`, `FileSystemDeleter`

## 설계 결정 요약 (승인됨)

| 항목 | 결정 |
|---|---|
| M2 범위 | Docker(CLI) + 패키지캐시(CLI 우선) + node_modules/.venv(경로) 세 계열 모두 |
| CLI 결과 판정 | `CommandRunner`에 `runResult() → (stdout, exitCode)` 추가(기존 `run()` 유지) + 회수량은 before/after 실측 |
| 경로 크기 계산 | `DirectorySizer`로 직접 du. 증분 캐싱은 M3(Store 의존)로 이연 |
| 모듈 실행 | `DetectorRegistry` + 병렬 `scanAll()`, 미설치 도구 모듈 자동 숨김 |
| 휴면 판정 | 재발명 안 함 — NodeModules는 후보만 발행, 활성 보호는 M1 `ParentProjectActivitySignal`이 reclaim 시점 자동 `.protected` 강등 |
| reclaim 라우팅(승인 항목→소유 모듈) | M4(앱) 책임. M2는 각 모듈이 자기 scan+reclaim 완결 |

---

## 1. 아키텍처

### 신규 파일

```
Sources/DevSweepCore/
├── Detect/
│   ├── CleanupModule.swift       # 프로토콜 (scan + reclaim 완결 단위)
│   ├── DetectorRegistry.swift    # 모듈 병렬 scanAll() 집계, 미설치 skip
│   ├── DirectorySizer.swift      # FileManager enumerator du → Int64
│   ├── DockerModule.swift        # CLI 모듈
│   ├── PackageCacheModule.swift  # CLI 우선 + 경로 폴백
│   └── NodeModulesModule.swift   # 경로 모듈 (M1 Reclaimer 위임)
└── Process/
    └── CommandRunner.swift       # 확장: runResult() + CommandResult
```

### CleanupModule 프로토콜

설계문서 원안대로 scan + reclaim 둘 다 보유 — 각 모듈이 자기 영역의 완결 단위(scan은 절대 삭제 안 함).

```swift
public protocol CleanupModule: Sendable {
    var id: String { get }
    var displayName: String { get }
    /// 도구 미설치/비가용이면 false → registry가 숨김.
    func isAvailable() async -> Bool
    /// 후보 + 크기 + 안전등급만 산출. 삭제하지 않는다.
    func scan() async -> [CleanupItem]
    /// 회수 실행. dryRun이면 계획만, 미실행.
    func reclaim(_ items: [CleanupItem], dryRun: Bool) async -> [ReclaimOutcome]
}
```

### CommandRunner 확장

```swift
public struct CommandResult: Sendable, Equatable {
    public let stdout: String
    public let exitCode: Int32
}

public protocol CommandRunner: Sendable {
    /// stdout + 종료 코드. CLI 회수 성공 판정에 필요.
    func runResult(_ executable: String, _ args: [String]) async throws -> CommandResult
    /// 편의: stdout만 (기존 호출부 호환). 기본 구현은 runResult().stdout.
    func run(_ executable: String, _ args: [String]) async throws -> String
}

extension CommandRunner {
    public func run(_ executable: String, _ args: [String]) async throws -> String {
        try await runResult(executable, args).stdout
    }
}
```

`ProcessCommandRunner`는 `runResult` 구현(Process.terminationStatus 캡처). 기존 M1 신호(process/crontab)는 `run()` 그대로 사용 — 호환 유지.

### DirectorySizer

```swift
public struct DirectorySizer: Sendable {
    private let fileManager: FileManager
    public init(fileManager: FileManager = .default)
    /// 경로 하위 전체 바이트 합. 심볼릭 링크는 따라가지 않음. 접근 불가 항목은 건너뜀.
    public func size(of path: String) -> Int64
}
```

### DetectorRegistry

```swift
public struct DetectorRegistry: Sendable {
    private let modules: [any CleanupModule]
    public init(modules: [any CleanupModule])
    /// isAvailable() == true 인 모듈만 scan() 동시 실행, 결과 머지.
    public func scanAll() async -> [CleanupItem]
    /// 모듈별 그룹이 필요한 호출부용.
    public func scanGrouped() async -> [(module: String, items: [CleanupItem])]
}
```

---

## 2. 모듈별 동작

### ① DockerModule (CLI)

- `isAvailable()` → `docker` 실행 가능 + daemon 응답(`docker system df` exit 0).
- `scan()` → `docker system df`(가능하면 `--format '{{json .}}'`) 파싱, **하위 동작별 별도 CleanupItem**(안전등급 차등):

  | 항목 | reclaimMethod | safety |
  |---|---|---|
  | 빌드캐시 | `.cliCommand("docker", ["builder","prune","-f"])` | `.autoSafe` |
  | dangling 이미지 | `.cliCommand("docker", ["image","prune","-f"])` | `.autoSafe` |
  | 미사용 이미지 전체 | `.cliCommand("docker", ["image","prune","-a","-f"])` | `.reviewNeeded` |

  모두 `path=nil`. **`--volumes` 절대 미포함** (DB 데이터 볼륨 보호 — 2026-06-06 사용자 정책).
- `reclaim(items, dryRun)`:
  - dryRun → 각 항목 `.dryRun(plannedBytes:)` (scan 예측치)
  - 실제 → before(`docker system df`) 측정 → `runResult`로 prune 실행 → `exitCode != 0` 이면 `.failed(message:)` → after 측정 → `.deleted(bytes: max(0, before − after))`

### ② PackageCacheModule (CLI 우선 + 경로 폴백)

- 도구별 개별 `isAvailable()`(pnpm/npm/uv/bun/gradle) → 설치된 것만 항목 발행, 전부 `.autoSafe`.
- CLI 보유 도구 → `.cliCommand`: `pnpm store prune` / `npm cache clean --force` / `uv cache clean` / `bun pm cache rm`. 크기는 캐시 경로 du 추정(표시용).
- 깔끔한 prune CLI 없는 경우(gradle) → `~/.gradle/caches` **경로 삭제** `.deletePath(toTrash:false)` 폴백.
- `reclaim`: cliCommand 항목은 Docker와 동일 before/after 방식, deletePath 항목은 **주입된 M1 `Reclaimer`에 위임**.

### ③ NodeModulesModule (경로, M1 위임)

- `scan()` → 설정된 dev 루트(`~/Documents/dev` 등) 하위 `node_modules`/`.venv`/`venv` 열거. 각 `DirectorySizer`로 크기, `lastUsed`=부모 프로젝트 최근 소스 mtime(표시용), 전부 `.reviewNeeded`, `.deletePath(toTrash:false)`.
- 보호 루트(gprecious-marketplace, research-engine 등 설정값)는 발행 제외.
- `reclaim()` → 주입된 M1 `Reclaimer`에 그대로 위임 → **활성 프로젝트는 `ParentProjectActivitySignal`이 reclaim 시점 자동 `.protected` 강등**(휴면 판정 재발명 없음).

---

## 3. 안전 모델 (M1 계약 유지)

- **경로 삭제는 전부 M1 `Reclaimer` 경유** → dry-run 미삭제 + protected skip + 활성검사 불변식 자동 상속. M2는 새 삭제 경로를 만들지 않는다.
- **CLI 회수는 도구 자체 안전성에 의존** — `path=nil`이라 활성검사 비대상. docker/pnpm 등은 사용 중 리소스를 prune하지 않으며, M1이 "CLI 우선(state-aware)"을 택한 이유와 일치. 위험한 광범위 동작(`image prune -a`)은 `.reviewNeeded`로 사용자 승인 강제.
- **Docker 볼륨 절대 미접근** — 어떤 prune 명령에도 `--volumes` 미포함.

## 4. 테스트 전략 (TDD, 위험도순)

| 대상 | 방식 |
|---|---|
| CommandRunner 확장 | `ProcessCommandRunner.runResult` exit code — `/bin/sh -c 'exit 3'` 으로 검증 |
| DirectorySizer | TempDir 픽스처에 알려진 크기 파일 → 합계 검증, 심링크 미추적 |
| DockerModule | MockCommandRunner에 canned `system df`/`prune` stdout + exit code 주입 → scan 항목·안전등급 차등, reclaim before/after 회수량, exit≠0 시 `.failed`. 실제 docker 무의존 |
| PackageCacheModule | MockCommandRunner(CLI) + TempDir(gradle 경로 폴백), 미설치 도구 skip |
| NodeModulesModule | TempDir 픽스처(휴면/활성 프로젝트) → 휴면만 후보; SafetyLayer 통합으로 활성은 `.protected` 강등 회귀(M1 신호 재사용) |
| DetectorRegistry | mock 모듈 등록 → 병렬 scan 머지 + unavailable skip |
| 불변식 회귀 | M1 ReclaimerTests/pyiri 테스트는 계속 green 유지 (M2가 안전 경로를 안 바꿈) |

- 테스트 더블은 M1 자산 재사용: `MockCommandRunner`, `TempDir`, `RecordingDeleter`. MockCommandRunner는 `runResult` 지원하도록 확장(exit code 맵 추가).

## 5. 명시적 비범위 (YAGNI)

- 증분 크기 캐싱(mtime 불변 재사용) → M3(Store 의존)
- 승인 항목 → 소유 모듈 reclaim 라우팅 → M4(앱)
- Xcode/빌드산출물/AI에이전트 디텍터 → 후속(설계문서상 Pro 모듈)
- 메뉴바·알림·StoreKit → M4~M6

## 다음 단계

writing-plans로 M2 구현 계획 작성. herdr 3단계 패턴 적용 가능: foundation(CommandRunner 확장 + CleanupModule/DirectorySizer/Registry) → 병렬 leaf(Docker/PackageCache/NodeModules 모듈 각각) → 통합(Registry 집계 + 회귀).
