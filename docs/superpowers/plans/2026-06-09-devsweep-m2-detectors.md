# DevSweep Milestone 2 — Detector 모듈 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** M1 Safety Layer 위에 개발 도구 캐시·산출물(Docker / 패키지 캐시 / node_modules)을 탐지·집계·회수하는 Detector 모듈 계층을 TDD로 추가한다.

**Architecture:** `CleanupModule` 프로토콜(scan+reclaim 완결 단위)을 세 모듈이 구현하고, `DetectorRegistry`가 가용 모듈만 병렬 scan해 집계한다. 경로 삭제는 전부 M1 `Reclaimer`에 위임(안전 불변식 상속), CLI 회수(docker/pnpm 등)는 `CommandRunner.runResult()`의 종료코드 + before/after 실측으로 판정한다. M1 코드는 한 줄도 깨지 않는다(프로토콜 확장은 default extension으로 하위호환).

**Tech Stack:** Swift 6.0 / SPM (단일 `DevSweepCore` 타깃, 파일 자동 발견) / Swift Testing (`import Testing`, `@Test`, `#expect`). 작업 디렉토리는 항상 `DevSweep/`. 브랜치 `design/devsweep-menubar-cleaner`.

**Spec:** `docs/superpowers/specs/2026-06-09-devsweep-m2-detectors-design.md`

---

## Execution Topology (herdr 3단계)

[[herdr-worktree-parallel]] 패턴. 같은 SPM 패키지를 병렬 구현하므로 worktree 격리.

| Phase | Tasks | Worker | Effort | 비고 |
|---|---|---|---|---|
| 1 Foundation | Task 1–5 | claude 단일 | ultracode | 공유 프로토콜/헬퍼/테스트 더블. 여기서만 기존 파일 수정. blast radius 최대. |
| 2 Leaf (병렬) | Task 6 / 7 / 8 | claude + codex, 각자 `git worktree` | 기본 | 각 워커는 **서로 disjoint한 신규 파일만** 추가(모듈 1개 + 테스트 1개). Package.swift·기존 헬퍼·foundation 파일 수정 금지. |
| 3 Integration | Task 9–10 | claude 단일 | ultracode | leaf 머지 후 팩토리 + 레지스트리 통합 테스트 + 전체 회귀 게이트. |

**완료 판정 불변식:** 워커 DONE 텍스트/agent-status 불신([[feedback-herdr-codex-skill-builds]]). orchestrator가 직접 `swift test` 실행한 결과가 ground truth. Phase 2 머지 전 `comm -12 <(git diff --name-only) ...`로 leaf 간 변경 파일 겹침 0 확인.

---

## File Structure

신규 (Sources):
```
DevSweep/Sources/DevSweepCore/
├── Detect/
│   ├── CleanupModule.swift        # [Task 4] 프로토콜: scan + reclaim 완결 단위
│   ├── DetectorRegistry.swift     # [Task 5] 모듈 병렬 scanAll/scanGrouped, 미가용 skip
│   ├── DirectorySizer.swift       # [Task 3] 경로 하위 바이트 합 (심링크 미추적)
│   ├── DockerModule.swift         # [Task 6/leaf A] docker CLI 모듈, --volumes 금지
│   ├── PackageCacheModule.swift   # [Task 7/leaf B] pnpm/npm/uv/bun CLI + gradle 경로폴백
│   ├── NodeModulesModule.swift    # [Task 8/leaf C] node_modules/.venv, M1 Reclaimer 위임
│   └── DefaultDetectorRegistry.swift  # [Task 9] 프로덕션 팩토리 (cache vs project 안전계층 분리)
```

수정 (기존, **Phase 1에서만**):
```
DevSweep/Sources/DevSweepCore/Process/CommandRunner.swift       # [Task 1] runResult + CommandResult
DevSweep/Sources/DevSweepCore/Process/ProcessCommandRunner.swift # [Task 1] runResult 구현
DevSweep/Tests/DevSweepCoreTests/Support/MockCommandRunner.swift # [Task 1] runResult 하위호환 conformance
```

신규 (Tests):
```
DevSweep/Tests/DevSweepCoreTests/
├── Support/ScriptedCommandRunner.swift   # [Task 2] FIFO·전체명령키 + 종료코드 테스트 더블
├── Support/MockCleanupModule.swift        # [Task 4] CleanupModule 테스트 더블
├── DirectorySizerTests.swift              # [Task 3]
├── DetectorRegistryTests.swift            # [Task 5]
├── DockerModuleTests.swift                # [Task 6/leaf A]
├── PackageCacheModuleTests.swift          # [Task 7/leaf B]
├── NodeModulesModuleTests.swift           # [Task 8/leaf C]
└── DefaultDetectorRegistryTests.swift     # [Task 9]
```

---

## Phase 1 — Foundation (Task 1–5)

### Task 1: CommandRunner를 종료코드 인지로 확장

M1 신호(process/crontab)는 stdout만 쓰지만 CLI 회수 성공 판정엔 종료코드가 필요하다. `runResult()`를 프로토콜 요구사항으로 올리고 기존 `run()`은 default extension으로 강등 → 모든 M1 호출부 무수정 통과.

**Files:**
- Modify: `DevSweep/Sources/DevSweepCore/Process/CommandRunner.swift` (전체 교체)
- Modify: `DevSweep/Sources/DevSweepCore/Process/ProcessCommandRunner.swift` (전체 교체)
- Modify: `DevSweep/Tests/DevSweepCoreTests/Support/MockCommandRunner.swift` (전체 교체)

- [ ] **Step 1: 실패 테스트 작성** — `DevSweep/Tests/DevSweepCoreTests/Support/MockCommandRunner.swift` 끝에 추가

```swift
@Test func processCommandRunnerCapturesExitCode() async throws {
    let runner = ProcessCommandRunner()
    let result = try await runner.runResult("/bin/sh", ["-c", "exit 3"])
    #expect(result.exitCode == 3)
    #expect(result.stdout.isEmpty)
}

@Test func runDefaultExtensionStillReturnsStdoutOnly() async throws {
    let runner = ProcessCommandRunner()
    let out = try await runner.run("/bin/echo", ["devsweep-ext"])
    #expect(out.trimmingCharacters(in: .whitespacesAndNewlines) == "devsweep-ext")
}
```

- [ ] **Step 2: 실패 확인**

Run: `cd DevSweep && swift test --filter processCommandRunnerCapturesExitCode`
Expected: FAIL — build error: `value of type 'ProcessCommandRunner' has no member 'runResult'`

- [ ] **Step 3: 프로토콜 확장** — `CommandRunner.swift` 전체를 아래로 교체

```swift
/// stdout + 종료 코드. CLI 회수 성공 판정에 필요.
public struct CommandResult: Sendable, Equatable {
    public let stdout: String
    public let exitCode: Int32

    public init(stdout: String, exitCode: Int32) {
        self.stdout = stdout
        self.exitCode = exitCode
    }
}

/// Abstraction over running an external command. `runResult` is the requirement;
/// `run` is a convenience default (stdout only) so M1 call sites (lsof, crontab) are
/// unchanged.
public protocol CommandRunner: Sendable {
    /// Run `executable` with `args`, returning stdout + exit code.
    /// A non-zero exit does NOT throw; it is reported via `CommandResult.exitCode`.
    func runResult(_ executable: String, _ args: [String]) async throws -> CommandResult

    /// Convenience: stdout only. Default implementation delegates to `runResult`.
    func run(_ executable: String, _ args: [String]) async throws -> String
}

extension CommandRunner {
    public func run(_ executable: String, _ args: [String]) async throws -> String {
        try await runResult(executable, args).stdout
    }
}
```

- [ ] **Step 4: ProcessCommandRunner 구현** — `ProcessCommandRunner.swift` 전체를 아래로 교체

```swift
import Foundation

/// Real CommandRunner backed by Foundation.Process. Thin on purpose — parsing logic
/// lives in the callers (signals, modules), not here.
public struct ProcessCommandRunner: CommandRunner {
    public init() {}

    public func runResult(_ executable: String, _ args: [String]) async throws -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = args
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()  // discard stderr

        try process.run()
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let text = String(data: data, encoding: .utf8) ?? ""
        return CommandResult(stdout: text, exitCode: process.terminationStatus)
    }
}
```

- [ ] **Step 5: MockCommandRunner 하위호환 conformance** — `MockCommandRunner.swift` 전체를 아래로 교체 (기존 M1 테스트 2개 보존)

```swift
import Foundation
import Testing
@testable import DevSweepCore

/// Test double: canned stdout + optional exit code keyed by executable. Records nothing.
/// `exitCodes` defaults to empty so M1 call sites `MockCommandRunner(outputs:)` still compile.
struct MockCommandRunner: CommandRunner {
    let outputs: [String: String]
    var exitCodes: [String: Int32] = [:]

    func runResult(_ executable: String, _ args: [String]) async throws -> CommandResult {
        CommandResult(stdout: outputs[executable] ?? "", exitCode: exitCodes[executable] ?? 0)
    }
}

@Test func mockCommandRunnerReturnsCannedOutput() async throws {
    let runner = MockCommandRunner(outputs: ["/usr/bin/crontab": "0 3 * * * echo hi\n"])
    let out = try await runner.run("/usr/bin/crontab", ["-l"])
    #expect(out.contains("echo hi"))
}

@Test func mockCommandRunnerReturnsCannedExitCode() async throws {
    let runner = MockCommandRunner(outputs: ["/bin/x": ""], exitCodes: ["/bin/x": 7])
    let result = try await runner.runResult("/bin/x", [])
    #expect(result.exitCode == 7)
}

@Test func processCommandRunnerCapturesEcho() async throws {
    let runner = ProcessCommandRunner()
    let out = try await runner.run("/bin/echo", ["devsweep-ok"])
    #expect(out.trimmingCharacters(in: .whitespacesAndNewlines) == "devsweep-ok")
}

@Test func processCommandRunnerCapturesExitCode() async throws {
    let runner = ProcessCommandRunner()
    let result = try await runner.runResult("/bin/sh", ["-c", "exit 3"])
    #expect(result.exitCode == 3)
    #expect(result.stdout.isEmpty)
}

@Test func runDefaultExtensionStillReturnsStdoutOnly() async throws {
    let runner = ProcessCommandRunner()
    let out = try await runner.run("/bin/echo", ["devsweep-ext"])
    #expect(out.trimmingCharacters(in: .whitespacesAndNewlines) == "devsweep-ext")
}
```

- [ ] **Step 6: 전체 테스트 통과 확인** (M1 회귀 포함 — `run()`이 default extension으로 살아있는지)

Run: `cd DevSweep && swift test`
Expected: PASS — 기존 33 + 신규 2 = 35 tests passed (M1 신호 테스트 전부 green)

- [ ] **Step 7: 커밋**

```bash
git add DevSweep/Sources/DevSweepCore/Process/CommandRunner.swift \
        DevSweep/Sources/DevSweepCore/Process/ProcessCommandRunner.swift \
        DevSweep/Tests/DevSweepCoreTests/Support/MockCommandRunner.swift
git commit -m "feat(devsweep): CommandRunner.runResult + CommandResult (M1 run() 하위호환)"
```

---

### Task 2: ScriptedCommandRunner 테스트 더블

Docker 모듈은 같은 명령(`system df`)을 회수 전·후로 두 번 호출해 **다른** 출력을 받아야 한다. `MockCommandRunner`는 executable 단일 키라 이를 못 한다. 전체 명령(executable+args)을 키로, 호출별 FIFO 응답을 주는 actor 더블을 추가한다.

**Files:**
- Create: `DevSweep/Tests/DevSweepCoreTests/Support/ScriptedCommandRunner.swift`

- [ ] **Step 1: 실패 테스트 작성** (파일 생성, 더블 + 자체 검증 동시 작성)

```swift
import Foundation
import Testing
@testable import DevSweepCore

/// Test double keyed by the FULL command (`exe arg1 arg2 ...`). Each key holds a FIFO
/// queue of responses, so the same command can return different output across calls
/// (docker before/after measurement). Unscripted commands return empty + exit 0.
actor ScriptedCommandRunner: CommandRunner {
    struct Response: Sendable { let stdout: String; let exitCode: Int32
        init(stdout: String = "", exitCode: Int32 = 0) { self.stdout = stdout; self.exitCode = exitCode }
    }

    private var queues: [String: [Response]]
    private(set) var calls: [String] = []

    init(_ scripted: [String: [Response]]) { self.queues = scripted }

    private func key(_ exe: String, _ args: [String]) -> String {
        ([exe] + args).joined(separator: " ")
    }

    func runResult(_ executable: String, _ args: [String]) async throws -> CommandResult {
        let k = key(executable, args)
        calls.append(k)
        if var queue = queues[k], !queue.isEmpty {
            let response = queue.removeFirst()
            queues[k] = queue
            return CommandResult(stdout: response.stdout, exitCode: response.exitCode)
        }
        return CommandResult(stdout: "", exitCode: 0)
    }

    var callCount: Int { calls.count }
}

@Test func scriptedRunnerReturnsFifoPerCommand() async throws {
    let runner = ScriptedCommandRunner([
        "/bin/x a": [.init(stdout: "first", exitCode: 0), .init(stdout: "second", exitCode: 0)]
    ])
    let r1 = try await runner.runResult("/bin/x", ["a"])
    let r2 = try await runner.runResult("/bin/x", ["a"])
    #expect(r1.stdout == "first")
    #expect(r2.stdout == "second")
    #expect(await runner.callCount == 2)
}

@Test func scriptedRunnerUnscriptedIsEmptySuccess() async throws {
    let runner = ScriptedCommandRunner([:])
    let r = try await runner.runResult("/bin/missing", ["z"])
    #expect(r.stdout.isEmpty)
    #expect(r.exitCode == 0)
}

@Test func scriptedRunnerCarriesExitCode() async throws {
    let runner = ScriptedCommandRunner(["/bin/fail q": [.init(exitCode: 1)]])
    let r = try await runner.runResult("/bin/fail", ["q"])
    #expect(r.exitCode == 1)
}
```

- [ ] **Step 2: 실패 확인** (컴파일은 되지만 새 테스트가 최초 실행 — 더블 자체가 SUT)

Run: `cd DevSweep && swift test --filter scriptedRunnerReturnsFifoPerCommand`
Expected: PASS (더블 + 자체 테스트를 한 번에 작성한 케이스 — RED 단계는 "파일 부재"였고 작성 직후 GREEN)

> 참고: 테스트 더블은 그 자체가 구현이므로 표준 RED→GREEN 분리가 어렵다. 자체 검증 테스트로 동작을 고정하는 것으로 갈음한다.

- [ ] **Step 3: 커밋**

```bash
git add DevSweep/Tests/DevSweepCoreTests/Support/ScriptedCommandRunner.swift
git commit -m "test(devsweep): ScriptedCommandRunner (전체명령 키 + FIFO + 종료코드)"
```

---

### Task 3: DirectorySizer

경로 하위 전체 바이트 합. M1 `ParentProjectActivitySignal`과 동일한 수동 재귀 스타일(심링크 미추적: `attributesOfItem`은 lstat 의미라 링크를 따라가지 않음).

**Files:**
- Create: `DevSweep/Sources/DevSweepCore/Detect/DirectorySizer.swift`
- Create: `DevSweep/Tests/DevSweepCoreTests/DirectorySizerTests.swift`

- [ ] **Step 1: 실패 테스트 작성** — `DirectorySizerTests.swift`

```swift
import Foundation
import Testing
@testable import DevSweepCore

@Test func directorySizerSumsKnownFileSizes() {
    let tmp = TempDir(); defer { tmp.cleanup() }
    tmp.writeFile("a.txt", String(repeating: "x", count: 100))   // 100 bytes
    tmp.writeFile("sub/b.txt", String(repeating: "y", count: 50)) // 50 bytes
    let sizer = DirectorySizer()
    #expect(sizer.size(of: tmp.url.path) == 150)
}

@Test func directorySizerDoesNotFollowSymlinks() throws {
    let tmp = TempDir(); defer { tmp.cleanup() }
    let target = tmp.writeFile("real.txt", String(repeating: "z", count: 200))
    let linkPath = (tmp.url.path as NSString).appendingPathComponent("link.txt")
    try FileManager.default.createSymbolicLink(atPath: linkPath, withDestinationPath: target)
    let sizer = DirectorySizer()
    // Only real.txt (200) counts; the symlink is skipped, not followed.
    #expect(sizer.size(of: tmp.url.path) == 200)
}

@Test func directorySizerReturnsZeroForMissingPath() {
    let sizer = DirectorySizer()
    #expect(sizer.size(of: "/nonexistent/devsweep/path") == 0)
}
```

- [ ] **Step 2: 실패 확인**

Run: `cd DevSweep && swift test --filter directorySizerSumsKnownFileSizes`
Expected: FAIL — build error: `cannot find 'DirectorySizer' in scope`

- [ ] **Step 3: 구현** — `DirectorySizer.swift`

```swift
import Foundation

/// Computes the total byte size under a path. Manual recursion (mirrors
/// ParentProjectActivitySignal) so behavior is deterministic: symlinks are NOT
/// followed (attributesOfItem uses lstat), unreadable entries are skipped.
public struct DirectorySizer: Sendable {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    /// Total bytes of regular files under `path`. `0` if the path is missing/unreadable.
    public func size(of path: String) -> Int64 {
        var total: Int64 = 0
        accumulate(path, into: &total)
        return total
    }

    private func accumulate(_ path: String, into total: inout Int64) {
        guard let attrs = try? fileManager.attributesOfItem(atPath: path) else { return }
        let type = attrs[.type] as? FileAttributeType
        switch type {
        case .typeSymbolicLink:
            return  // never follow links
        case .typeDirectory:
            guard let entries = try? fileManager.contentsOfDirectory(atPath: path) else { return }
            for entry in entries {
                accumulate((path as NSString).appendingPathComponent(entry), into: &total)
            }
        case .typeRegular:
            if let size = attrs[.size] as? Int64 { total += size }
        default:
            return
        }
    }
}
```

- [ ] **Step 4: 통과 확인**

Run: `cd DevSweep && swift test --filter directorySizer`
Expected: PASS — 3 tests passed

- [ ] **Step 5: 커밋**

```bash
git add DevSweep/Sources/DevSweepCore/Detect/DirectorySizer.swift \
        DevSweep/Tests/DevSweepCoreTests/DirectorySizerTests.swift
git commit -m "feat(devsweep): DirectorySizer (재귀 du, 심링크 미추적)"
```

---

### Task 4: CleanupModule 프로토콜 + 테스트 더블

각 모듈이 자기 영역의 scan+reclaim 완결 단위. scan은 절대 삭제하지 않는다(후보+크기+안전등급만).

**Files:**
- Create: `DevSweep/Sources/DevSweepCore/Detect/CleanupModule.swift`
- Create: `DevSweep/Tests/DevSweepCoreTests/Support/MockCleanupModule.swift`

- [ ] **Step 1: 실패 테스트 작성** — `MockCleanupModule.swift` (더블 + 자체 검증)

```swift
import Foundation
import Testing
@testable import DevSweepCore

/// Test double for CleanupModule. Returns configured availability + items; reclaim
/// reports each item as a dry-run plan (no side effects).
struct MockCleanupModule: CleanupModule {
    let id: String
    let displayName: String
    let available: Bool
    let items: [CleanupItem]

    func isAvailable() async -> Bool { available }
    func scan() async -> [CleanupItem] { items }
    func reclaim(_ items: [CleanupItem], dryRun: Bool) async -> [ReclaimOutcome] {
        items.map { ReclaimOutcome(item: $0, status: .dryRun(plannedBytes: $0.sizeBytes)) }
    }
}

private func cliItem(_ id: String, _ bytes: Int64) -> CleanupItem {
    CleanupItem(id: id, path: nil, sizeBytes: bytes, lastUsed: nil,
                safety: .autoSafe, reclaimMethod: .cliCommand(executable: "/usr/bin/env", arguments: []))
}

@Test func mockCleanupModuleReportsConfiguredState() async {
    let m = MockCleanupModule(id: "m", displayName: "M", available: true, items: [cliItem("m:x", 42)])
    #expect(await m.isAvailable() == true)
    #expect(await m.scan().map(\.id) == ["m:x"])
    let outcomes = await m.reclaim(await m.scan(), dryRun: true)
    #expect(outcomes.first?.status == .dryRun(plannedBytes: 42))
}
```

- [ ] **Step 2: 실패 확인**

Run: `cd DevSweep && swift test --filter mockCleanupModuleReportsConfiguredState`
Expected: FAIL — build error: `cannot find type 'CleanupModule' in scope`

- [ ] **Step 3: 구현** — `CleanupModule.swift`

```swift
/// A self-contained cleanup domain: it discovers its own candidates and reclaims them.
/// `scan()` is read-only (never deletes). `reclaim()` performs (or plans, when dryRun)
/// the actual reclaim — path-based modules delegate to the M1 Reclaimer; CLI-based
/// modules invoke the tool's own prune command and measure before/after.
public protocol CleanupModule: Sendable {
    var id: String { get }
    var displayName: String { get }

    /// False when the underlying tool is absent/unresponsive → the registry hides it.
    func isAvailable() async -> Bool

    /// Candidates with size + safety class only. Never deletes.
    func scan() async -> [CleanupItem]

    /// Reclaim `items`. When `dryRun`, produces a plan and performs no side effects.
    func reclaim(_ items: [CleanupItem], dryRun: Bool) async -> [ReclaimOutcome]
}
```

- [ ] **Step 4: 통과 확인**

Run: `cd DevSweep && swift test --filter mockCleanupModuleReportsConfiguredState`
Expected: PASS

- [ ] **Step 5: 커밋**

```bash
git add DevSweep/Sources/DevSweepCore/Detect/CleanupModule.swift \
        DevSweep/Tests/DevSweepCoreTests/Support/MockCleanupModule.swift
git commit -m "feat(devsweep): CleanupModule 프로토콜 + MockCleanupModule"
```

---

### Task 5: DetectorRegistry

가용 모듈만 병렬 scan, 결정적 순서(모듈 인덱스)로 머지. 미설치 도구 모듈은 자동 숨김.

**Files:**
- Create: `DevSweep/Sources/DevSweepCore/Detect/DetectorRegistry.swift`
- Create: `DevSweep/Tests/DevSweepCoreTests/DetectorRegistryTests.swift`

- [ ] **Step 1: 실패 테스트 작성** — `DetectorRegistryTests.swift`

```swift
import Foundation
import Testing
@testable import DevSweepCore

private func cliItem(_ id: String, _ bytes: Int64) -> CleanupItem {
    CleanupItem(id: id, path: nil, sizeBytes: bytes, lastUsed: nil,
                safety: .autoSafe, reclaimMethod: .cliCommand(executable: "/usr/bin/env", arguments: []))
}

@Test func registrySkipsUnavailableModules() async {
    let a = MockCleanupModule(id: "a", displayName: "A", available: true, items: [cliItem("a:x", 10)])
    let b = MockCleanupModule(id: "b", displayName: "B", available: false, items: [cliItem("b:y", 20)])
    let reg = DetectorRegistry(modules: [a, b])
    let items = await reg.scanAll()
    #expect(items.map(\.id) == ["a:x"])
}

@Test func registryMergesAvailableModulesInIndexOrder() async {
    let a = MockCleanupModule(id: "a", displayName: "A", available: true, items: [cliItem("a:x", 10)])
    let b = MockCleanupModule(id: "b", displayName: "B", available: true, items: [cliItem("b:y", 20)])
    let reg = DetectorRegistry(modules: [a, b])
    let grouped = await reg.scanGrouped()
    #expect(grouped.map(\.module) == ["a", "b"])
    #expect(grouped.flatMap(\.items).map(\.id) == ["a:x", "b:y"])
}

@Test func registryEmptyWhenAllUnavailable() async {
    let a = MockCleanupModule(id: "a", displayName: "A", available: false, items: [cliItem("a:x", 10)])
    let reg = DetectorRegistry(modules: [a])
    #expect(await reg.scanAll().isEmpty)
    #expect(await reg.scanGrouped().isEmpty)
}
```

- [ ] **Step 2: 실패 확인**

Run: `cd DevSweep && swift test --filter registrySkipsUnavailableModules`
Expected: FAIL — build error: `cannot find 'DetectorRegistry' in scope`

- [ ] **Step 3: 구현** — `DetectorRegistry.swift`

```swift
/// Runs every available module's scan concurrently and merges the results. Modules whose
/// `isAvailable()` is false are skipped entirely. Output order is deterministic (module
/// declaration order), independent of which scan finishes first.
public struct DetectorRegistry: Sendable {
    private let modules: [any CleanupModule]

    public init(modules: [any CleanupModule]) {
        self.modules = modules
    }

    /// Flat list of all candidates from available modules, in module declaration order.
    public func scanAll() async -> [CleanupItem] {
        await scanGrouped().flatMap(\.items)
    }

    /// Candidates grouped by owning module id, in module declaration order. Modules that
    /// produce no items but are available are omitted from the grouping.
    public func scanGrouped() async -> [(module: String, items: [CleanupItem])] {
        let collected: [(Int, String, [CleanupItem])] =
        await withTaskGroup(of: (Int, String, [CleanupItem])?.self) { group in
            for (index, module) in modules.enumerated() {
                group.addTask {
                    guard await module.isAvailable() else { return nil }
                    let items = await module.scan()
                    return items.isEmpty ? nil : (index, module.id, items)
                }
            }
            var results: [(Int, String, [CleanupItem])] = []
            for await result in group {
                if let result { results.append(result) }
            }
            return results
        }
        return collected
            .sorted { $0.0 < $1.0 }
            .map { (module: $0.1, items: $0.2) }
    }
}
```

- [ ] **Step 4: 통과 확인**

Run: `cd DevSweep && swift test --filter registry`
Expected: PASS — 3 tests passed

- [ ] **Step 5: 커밋 + Phase 1 게이트**

```bash
git add DevSweep/Sources/DevSweepCore/Detect/DetectorRegistry.swift \
        DevSweep/Tests/DevSweepCoreTests/DetectorRegistryTests.swift
git commit -m "feat(devsweep): DetectorRegistry 병렬 scan 집계 + 미가용 skip"
cd DevSweep && swift test   # 전체 게이트
```
Expected: PASS — M1 33 + Foundation 신규 모두 green. **이 커밋이 Phase 2 worktree들의 분기점.**

---

## Phase 2 — Leaf 모듈 (Task 6–8, worktree 병렬)

> 각 leaf는 Phase 1 마지막 커밋에서 `git worktree add /tmp/wt-<X> -b wt/<X> HEAD`로 분기. **신규 파일 2개(모듈+테스트)만 추가**, Package.swift·foundation·기존 헬퍼 수정 금지. 머지 시 충돌 0.

### Task 6 (leaf A): DockerModule

`docker system df` 파싱으로 하위 동작별 항목(안전등급 차등) 발행, 회수는 before/after 실측. **`--volumes` 어떤 명령에도 미포함** + reclaim 시 방어 가드.

**Files:**
- Create: `DevSweep/Sources/DevSweepCore/Detect/DockerModule.swift`
- Create: `DevSweep/Tests/DevSweepCoreTests/DockerModuleTests.swift`

- [ ] **Step 1: 실패 테스트 작성** — `DockerModuleTests.swift`

```swift
import Foundation
import Testing
@testable import DevSweepCore

private let dfJSON = """
{"Type":"Images","TotalCount":"10","Active":"3","Size":"5GB","Reclaimable":"2GB (40%)"}
{"Type":"Containers","TotalCount":"2","Active":"1","Size":"100MB","Reclaimable":"50MB (50%)"}
{"Type":"Local Volumes","TotalCount":"4","Active":"4","Size":"1GB","Reclaimable":"0B (0%)"}
{"Type":"Build Cache","TotalCount":"20","Active":"0","Size":"3GB","Reclaimable":"3GB"}
"""

private let dfAfterJSON = """
{"Type":"Images","TotalCount":"10","Active":"3","Size":"5GB","Reclaimable":"2GB (40%)"}
{"Type":"Build Cache","TotalCount":"0","Active":"0","Size":"1GB","Reclaimable":"1GB"}
"""

@Test func dockerUnavailableWhenSystemDfFails() async {
    let runner = ScriptedCommandRunner([
        "/usr/bin/env docker system df": [.init(exitCode: 1)]
    ])
    let module = DockerModule(runner: runner)
    #expect(await module.isAvailable() == false)
}

@Test func dockerScanEmitsThreeSafetyClassedActionsNeverVolumes() async {
    let runner = ScriptedCommandRunner([
        "/usr/bin/env docker system df --format {{json .}}": [.init(stdout: dfJSON)]
    ])
    let module = DockerModule(runner: runner)
    let items = await module.scan()

    #expect(items.map(\.id) == ["docker:build-cache", "docker:dangling-images", "docker:unused-images"])
    #expect(items[0].safety == .autoSafe)
    #expect(items[1].safety == .autoSafe)
    #expect(items[2].safety == .reviewNeeded)
    #expect(items.allSatisfy { $0.path == nil })

    // sizes parsed from df Reclaimable (base-1000): build cache 3GB, unused images 2GB.
    #expect(items[0].sizeBytes == 3_000_000_000)
    #expect(items[2].sizeBytes == 2_000_000_000)

    // NO --volumes anywhere.
    for item in items {
        if case let .cliCommand(_, args) = item.reclaimMethod {
            #expect(!args.contains("--volumes"))
        } else {
            Issue.record("docker items must be cliCommand")
        }
    }
    // exact commands
    if case let .cliCommand(_, a0) = items[0].reclaimMethod { #expect(a0 == ["docker", "builder", "prune", "-f"]) }
    if case let .cliCommand(_, a1) = items[1].reclaimMethod { #expect(a1 == ["docker", "image", "prune", "-f"]) }
    if case let .cliCommand(_, a2) = items[2].reclaimMethod { #expect(a2 == ["docker", "image", "prune", "-a", "-f"]) }
}

@Test func dockerReclaimMeasuresBeforeAfterDelta() async {
    // before total Size = 5GB+100MB+1GB+3GB = 9.1e9 ; after = 5GB+1GB = 6e9 ; delta = 3.1e9
    let runner = ScriptedCommandRunner([
        "/usr/bin/env docker system df --format {{json .}}": [
            .init(stdout: dfJSON),       // before
            .init(stdout: dfAfterJSON)   // after
        ],
        "/usr/bin/env docker builder prune -f": [.init(stdout: "deleted", exitCode: 0)]
    ])
    let module = DockerModule(runner: runner)
    let item = CleanupItem(id: "docker:build-cache", path: nil, sizeBytes: 3_000_000_000, lastUsed: nil,
                           safety: .autoSafe,
                           reclaimMethod: .cliCommand(executable: "/usr/bin/env",
                                                      arguments: ["docker", "builder", "prune", "-f"]))
    let outcomes = await module.reclaim([item], dryRun: false)
    #expect(outcomes.first?.status == .deleted(bytes: 3_100_000_000))
}

@Test func dockerReclaimDryRunDoesNotRunPrune() async {
    let runner = ScriptedCommandRunner([:])
    let module = DockerModule(runner: runner)
    let item = CleanupItem(id: "docker:build-cache", path: nil, sizeBytes: 999, lastUsed: nil,
                           safety: .autoSafe,
                           reclaimMethod: .cliCommand(executable: "/usr/bin/env",
                                                      arguments: ["docker", "builder", "prune", "-f"]))
    let outcomes = await module.reclaim([item], dryRun: true)
    #expect(outcomes.first?.status == .dryRun(plannedBytes: 999))
    #expect(await runner.callCount == 0)
}

@Test func dockerReclaimFailsOnNonZeroExit() async {
    let runner = ScriptedCommandRunner([
        "/usr/bin/env docker system df --format {{json .}}": [.init(stdout: dfJSON), .init(stdout: dfJSON)],
        "/usr/bin/env docker image prune -a -f": [.init(stdout: "err", exitCode: 1)]
    ])
    let module = DockerModule(runner: runner)
    let item = CleanupItem(id: "docker:unused-images", path: nil, sizeBytes: 0, lastUsed: nil,
                           safety: .reviewNeeded,
                           reclaimMethod: .cliCommand(executable: "/usr/bin/env",
                                                      arguments: ["docker", "image", "prune", "-a", "-f"]))
    let outcomes = await module.reclaim([item], dryRun: false)
    if case .failed = outcomes.first?.status {} else { Issue.record("expected .failed on exit 1") }
}

@Test func dockerReclaimRefusesVolumesCommand() async {
    let runner = ScriptedCommandRunner([:])
    let module = DockerModule(runner: runner)
    let evil = CleanupItem(id: "docker:evil", path: nil, sizeBytes: 0, lastUsed: nil,
                           safety: .autoSafe,
                           reclaimMethod: .cliCommand(executable: "/usr/bin/env",
                                                      arguments: ["docker", "system", "prune", "--volumes", "-f"]))
    let outcomes = await module.reclaim([evil], dryRun: false)
    if case let .failed(msg) = outcomes.first?.status { #expect(msg.contains("--volumes")) }
    else { Issue.record("expected .failed refusing --volumes") }
    #expect(await runner.callCount == 0)
}
```

- [ ] **Step 2: 실패 확인**

Run: `cd DevSweep && swift test --filter dockerScanEmitsThreeSafetyClassedActionsNeverVolumes`
Expected: FAIL — build error: `cannot find 'DockerModule' in scope`

- [ ] **Step 3: 구현** — `DockerModule.swift`

```swift
import Foundation

/// Detects reclaimable Docker space via the docker CLI. Emits one item per prune action
/// with a differentiated safety class. NEVER touches volumes (DB data protection — the
/// 2026-06-06 user policy): no command contains `--volumes`, and reclaim refuses any item
/// whose command does.
public struct DockerModule: CleanupModule {
    public let id = "docker"
    public let displayName = "Docker"

    private let runner: any CommandRunner
    private let executable: String
    private let argPrefix: [String]

    public init(
        runner: any CommandRunner,
        executable: String = "/usr/bin/env",
        argPrefix: [String] = ["docker"]
    ) {
        self.runner = runner
        self.executable = executable
        self.argPrefix = argPrefix
    }

    private func docker(_ args: [String]) -> (String, [String]) {
        (executable, argPrefix + args)
    }

    public func isAvailable() async -> Bool {
        let (exe, args) = docker(["system", "df"])
        guard let result = try? await runner.runResult(exe, args) else { return false }
        return result.exitCode == 0
    }

    public func scan() async -> [CleanupItem] {
        let (exe, args) = docker(["system", "df", "--format", "{{json .}}"])
        let reclaimable = (try? await runner.runResult(exe, args))
            .map { Self.parseReclaimable($0.stdout) } ?? [:]
        return [
            CleanupItem(
                id: "docker:build-cache", path: nil,
                sizeBytes: reclaimable["Build Cache"] ?? 0, lastUsed: nil,
                safety: .autoSafe,
                reclaimMethod: .cliCommand(executable: executable, arguments: argPrefix + ["builder", "prune", "-f"])
            ),
            CleanupItem(
                id: "docker:dangling-images", path: nil,
                sizeBytes: 0, lastUsed: nil,  // df can't isolate dangling subset; measured at reclaim
                safety: .autoSafe,
                reclaimMethod: .cliCommand(executable: executable, arguments: argPrefix + ["image", "prune", "-f"])
            ),
            CleanupItem(
                id: "docker:unused-images", path: nil,
                sizeBytes: reclaimable["Images"] ?? 0, lastUsed: nil,
                safety: .reviewNeeded,
                reclaimMethod: .cliCommand(executable: executable, arguments: argPrefix + ["image", "prune", "-a", "-f"])
            )
        ]
    }

    public func reclaim(_ items: [CleanupItem], dryRun: Bool) async -> [ReclaimOutcome] {
        var outcomes: [ReclaimOutcome] = []
        for item in items {
            guard case let .cliCommand(exe, args) = item.reclaimMethod else {
                outcomes.append(ReclaimOutcome(item: item, status: .failed(message: "DockerModule expects cliCommand items")))
                continue
            }
            if args.contains("--volumes") {
                outcomes.append(ReclaimOutcome(item: item, status: .failed(message: "refusing docker command with --volumes")))
                continue
            }
            if dryRun {
                outcomes.append(ReclaimOutcome(item: item, status: .dryRun(plannedBytes: item.sizeBytes)))
                continue
            }
            let before = await totalSizeBytes()
            let result = try? await runner.runResult(exe, args)
            guard let result, result.exitCode == 0 else {
                let message = result.map { "docker exited \($0.exitCode)" } ?? "docker command failed to launch"
                outcomes.append(ReclaimOutcome(item: item, status: .failed(message: message)))
                continue
            }
            let after = await totalSizeBytes()
            outcomes.append(ReclaimOutcome(item: item, status: .deleted(bytes: max(0, before - after))))
        }
        return outcomes
    }

    private func totalSizeBytes() async -> Int64 {
        let (exe, args) = docker(["system", "df", "--format", "{{json .}}"])
        guard let result = try? await runner.runResult(exe, args) else { return 0 }
        return Self.parseTotalSize(result.stdout)
    }

    /// Maps each df row Type → reclaimable bytes (from the "Reclaimable" column).
    static func parseReclaimable(_ stdout: String) -> [String: Int64] {
        var result: [String: Int64] = [:]
        for line in stdout.split(separator: "\n") {
            guard let data = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = obj["Type"] as? String,
                  let reclaimable = obj["Reclaimable"] as? String else { continue }
            result[type] = parseSize(reclaimable)
        }
        return result
    }

    /// Sums the "Size" column across all df rows (for before/after delta).
    static func parseTotalSize(_ stdout: String) -> Int64 {
        var total: Int64 = 0
        for line in stdout.split(separator: "\n") {
            guard let data = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let size = obj["Size"] as? String else { continue }
            total += parseSize(size)
        }
        return total
    }

    /// Parses a docker human size ("3GB", "2GB (40%)", "100MB", "0B") to bytes (base 1000).
    static func parseSize(_ raw: String) -> Int64 {
        let head = raw.split(separator: "(").first.map(String.init) ?? raw
        let trimmed = head.trimmingCharacters(in: .whitespaces)
        let units: [(String, Double)] = [("TB", 1e12), ("GB", 1e9), ("MB", 1e6), ("kB", 1e3), ("KB", 1e3), ("B", 1)]
        for (suffix, multiplier) in units where trimmed.hasSuffix(suffix) {
            let numberPart = trimmed.dropLast(suffix.count).trimmingCharacters(in: .whitespaces)
            return Double(numberPart).map { Int64($0 * multiplier) } ?? 0
        }
        return Int64(trimmed) ?? 0
    }
}
```

- [ ] **Step 4: 통과 확인**

Run: `cd DevSweep && swift test --filter docker`
Expected: PASS — 6 tests passed

- [ ] **Step 5: 커밋**

```bash
git add DevSweep/Sources/DevSweepCore/Detect/DockerModule.swift \
        DevSweep/Tests/DevSweepCoreTests/DockerModuleTests.swift
git commit -m "feat(devsweep): DockerModule (안전등급 차등 + before/after 실측 + --volumes 금지)"
```

---

### Task 7 (leaf B): PackageCacheModule

도구별 가용성 판정 → 설치된 것만 발행(전부 `.autoSafe`). CLI 보유 도구는 prune CLI, gradle는 경로 삭제 폴백(M1 Reclaimer 위임).

**Files:**
- Create: `DevSweep/Sources/DevSweepCore/Detect/PackageCacheModule.swift`
- Create: `DevSweep/Tests/DevSweepCoreTests/PackageCacheModuleTests.swift`

- [ ] **Step 1: 실패 테스트 작성** — `PackageCacheModuleTests.swift`

```swift
import Foundation
import Testing
@testable import DevSweepCore

private func emptyLayerReclaimer(_ deleter: any FileSystemDeleter) -> Reclaimer {
    Reclaimer(safety: SafetyLayer(signals: [], registry: ProtectedRegistry(userExcluded: [], systemProtected: [])),
              deleter: deleter)
}

@Test func packageCacheDefaultToolsHaveFiveEntries() {
    let tools = PackageCacheModule.defaultTools(home: "/Users/x")
    #expect(tools.map(\.id) == ["pnpm", "npm", "uv", "bun", "gradle"])
    // gradle is the only path-delete fallback
    if case .deletePath = tools.last!.reclaim {} else { Issue.record("gradle must be deletePath") }
}

@Test func packageCacheScanEmitsOnlyAvailableCliTools() async {
    let tmp = TempDir(); defer { tmp.cleanup() }
    let pnpmCache = tmp.makeDir("pnpm-store")
    let runner = ScriptedCommandRunner([
        "/usr/bin/env pnpm --version": [.init(stdout: "9.0.0", exitCode: 0)],
        "/usr/bin/env npm --version": [.init(exitCode: 127)]  // not installed
    ])
    let tools: [PackageCacheModule.Tool] = [
        .init(id: "pnpm", probe: .cli(executable: "/usr/bin/env", arguments: ["pnpm", "--version"]),
              cachePath: pnpmCache, reclaim: .cliCommand(executable: "/usr/bin/env", arguments: ["pnpm", "store", "prune"])),
        .init(id: "npm", probe: .cli(executable: "/usr/bin/env", arguments: ["npm", "--version"]),
              cachePath: tmp.url.appendingPathComponent("npm").path,
              reclaim: .cliCommand(executable: "/usr/bin/env", arguments: ["npm", "cache", "clean", "--force"]))
    ]
    let module = PackageCacheModule(tools: tools, runner: runner, reclaimer: emptyLayerReclaimer(RecordingDeleter()))
    let items = await module.scan()
    #expect(items.map(\.id) == ["package-cache:pnpm"])
    #expect(items.first?.safety == .autoSafe)
    #expect(items.first?.path == nil)  // CLI item → path nil
}

@Test func packageCacheGradleAvailableWhenCacheDirExists() async {
    let tmp = TempDir(); defer { tmp.cleanup() }
    let gradleCache = tmp.makeDir("gradle-caches")
    let tools: [PackageCacheModule.Tool] = [
        .init(id: "gradle", probe: .pathExists, cachePath: gradleCache, reclaim: .deletePath(toTrash: false))
    ]
    let module = PackageCacheModule(tools: tools, runner: ScriptedCommandRunner([:]),
                                    reclaimer: emptyLayerReclaimer(RecordingDeleter()))
    #expect(await module.isAvailable() == true)
    let items = await module.scan()
    #expect(items.map(\.id) == ["package-cache:gradle"])
    #expect(items.first?.path == gradleCache)  // deletePath item → path set
}

@Test func packageCacheGradleUnavailableWhenCacheMissing() async {
    let tools: [PackageCacheModule.Tool] = [
        .init(id: "gradle", probe: .pathExists, cachePath: "/nope/gradle", reclaim: .deletePath(toTrash: false))
    ]
    let module = PackageCacheModule(tools: tools, runner: ScriptedCommandRunner([:]),
                                    reclaimer: emptyLayerReclaimer(RecordingDeleter()))
    #expect(await module.isAvailable() == false)
    #expect(await module.scan().isEmpty)
}

@Test func packageCacheGradleReclaimDelegatesToM1Reclaimer() async {
    let tmp = TempDir(); defer { tmp.cleanup() }
    let gradleCache = tmp.makeDir("gradle-caches")
    let deleter = RecordingDeleter(bytesPerCall: 4096)
    let tools: [PackageCacheModule.Tool] = [
        .init(id: "gradle", probe: .pathExists, cachePath: gradleCache, reclaim: .deletePath(toTrash: false))
    ]
    let module = PackageCacheModule(tools: tools, runner: ScriptedCommandRunner([:]),
                                    reclaimer: emptyLayerReclaimer(deleter))
    let items = await module.scan()
    let outcomes = await module.reclaim(items, dryRun: false)
    #expect(outcomes.first?.status == .deleted(bytes: 4096))
    #expect(await deleter.calls.first == .init(path: gradleCache, toTrash: false))
}

@Test func packageCacheCliReclaimRunsCommandAndReportsDeleted() async {
    let tmp = TempDir(); defer { tmp.cleanup() }
    let pnpmCache = tmp.makeDir("pnpm-store")
    let runner = ScriptedCommandRunner([
        "/usr/bin/env pnpm --version": [.init(stdout: "9", exitCode: 0)],
        "/usr/bin/env pnpm store prune": [.init(stdout: "removed", exitCode: 0)]
    ])
    let tools: [PackageCacheModule.Tool] = [
        .init(id: "pnpm", probe: .cli(executable: "/usr/bin/env", arguments: ["pnpm", "--version"]),
              cachePath: pnpmCache, reclaim: .cliCommand(executable: "/usr/bin/env", arguments: ["pnpm", "store", "prune"]))
    ]
    let module = PackageCacheModule(tools: tools, runner: runner, reclaimer: emptyLayerReclaimer(RecordingDeleter()))
    let items = await module.scan()
    let outcomes = await module.reclaim(items, dryRun: false)
    if case .deleted = outcomes.first?.status {} else { Issue.record("expected .deleted for cli prune") }
    #expect(await runner.calls.contains("/usr/bin/env pnpm store prune"))
}

@Test func packageCacheCliReclaimFailsOnNonZeroExit() async {
    let tmp = TempDir(); defer { tmp.cleanup() }
    let runner = ScriptedCommandRunner([
        "/usr/bin/env uv cache clean": [.init(stdout: "boom", exitCode: 2)]
    ])
    let item = CleanupItem(id: "package-cache:uv", path: nil, sizeBytes: 10, lastUsed: nil, safety: .autoSafe,
                           reclaimMethod: .cliCommand(executable: "/usr/bin/env", arguments: ["uv", "cache", "clean"]))
    let tools: [PackageCacheModule.Tool] = [
        .init(id: "uv", probe: .cli(executable: "/usr/bin/env", arguments: ["uv", "--version"]),
              cachePath: tmp.url.appendingPathComponent("uv").path,
              reclaim: .cliCommand(executable: "/usr/bin/env", arguments: ["uv", "cache", "clean"]))
    ]
    let module = PackageCacheModule(tools: tools, runner: runner, reclaimer: emptyLayerReclaimer(RecordingDeleter()))
    let outcomes = await module.reclaim([item], dryRun: false)
    if case .failed = outcomes.first?.status {} else { Issue.record("expected .failed on exit 2") }
}
```

- [ ] **Step 2: 실패 확인**

Run: `cd DevSweep && swift test --filter packageCacheDefaultToolsHaveFiveEntries`
Expected: FAIL — build error: `cannot find 'PackageCacheModule' in scope`

- [ ] **Step 3: 구현** — `PackageCacheModule.swift`

```swift
import Foundation

/// Detects package-manager caches. CLI-first: tools with a real prune command use it
/// (state-aware). Tools without one (gradle) fall back to deleting the cache directory
/// via the M1 Reclaimer. All entries are `.autoSafe` (pure regenerable cache).
public struct PackageCacheModule: CleanupModule {
    public let id = "package-cache"
    public let displayName = "Package manager caches"

    /// How a tool's presence is detected.
    public enum ProbeMethod: Sendable {
        /// Tool is available if `executable args` exits 0 (e.g. `pnpm --version`).
        case cli(executable: String, arguments: [String])
        /// Tool is available if its cache directory exists (e.g. gradle).
        case pathExists
    }

    public struct Tool: Sendable {
        public let id: String
        public let probe: ProbeMethod
        public let cachePath: String
        public let reclaim: ReclaimMethod
        public init(id: String, probe: ProbeMethod, cachePath: String, reclaim: ReclaimMethod) {
            self.id = id; self.probe = probe; self.cachePath = cachePath; self.reclaim = reclaim
        }
    }

    private let tools: [Tool]
    private let runner: any CommandRunner
    private let reclaimer: Reclaimer
    private let sizer: DirectorySizer
    private let fileManager: FileManager

    public init(
        tools: [Tool],
        runner: any CommandRunner,
        reclaimer: Reclaimer,
        sizer: DirectorySizer = DirectorySizer(),
        fileManager: FileManager = .default
    ) {
        self.tools = tools
        self.runner = runner
        self.reclaimer = reclaimer
        self.sizer = sizer
        self.fileManager = fileManager
    }

    public func isAvailable() async -> Bool {
        for tool in tools where await isToolAvailable(tool) { return true }
        return false
    }

    public func scan() async -> [CleanupItem] {
        var items: [CleanupItem] = []
        for tool in tools where await isToolAvailable(tool) {
            let path: String? = { if case .deletePath = tool.reclaim { return tool.cachePath } else { return nil } }()
            items.append(CleanupItem(
                id: "package-cache:\(tool.id)",
                path: path,
                sizeBytes: sizer.size(of: tool.cachePath),
                lastUsed: nil,
                safety: .autoSafe,
                reclaimMethod: tool.reclaim
            ))
        }
        return items
    }

    public func reclaim(_ items: [CleanupItem], dryRun: Bool) async -> [ReclaimOutcome] {
        var outcomes: [ReclaimOutcome] = []
        for item in items {
            switch item.reclaimMethod {
            case .deletePath:
                // Path delete → M1 Reclaimer (dry-run + safety + accounting inherited).
                outcomes.append(contentsOf: await reclaimer.reclaim([item], dryRun: dryRun))
            case .cliCommand(let exe, let args):
                if dryRun {
                    outcomes.append(ReclaimOutcome(item: item, status: .dryRun(plannedBytes: item.sizeBytes)))
                    continue
                }
                let cachePath = tool(for: item)?.cachePath
                let before = cachePath.map { sizer.size(of: $0) } ?? 0
                let result = try? await runner.runResult(exe, args)
                guard let result, result.exitCode == 0 else {
                    let message = result.map { "\(item.id) exited \($0.exitCode)" } ?? "\(item.id) failed to launch"
                    outcomes.append(ReclaimOutcome(item: item, status: .failed(message: message)))
                    continue
                }
                let after = cachePath.map { sizer.size(of: $0) } ?? 0
                outcomes.append(ReclaimOutcome(item: item, status: .deleted(bytes: max(0, before - after))))
            }
        }
        return outcomes
    }

    private func tool(for item: CleanupItem) -> Tool? {
        tools.first { "package-cache:\($0.id)" == item.id }
    }

    private func isToolAvailable(_ tool: Tool) async -> Bool {
        switch tool.probe {
        case .cli(let exe, let args):
            guard let result = try? await runner.runResult(exe, args) else { return false }
            return result.exitCode == 0
        case .pathExists:
            return fileManager.fileExists(atPath: tool.cachePath)
        }
    }

    /// Production tool table. Cache paths are best-effort macOS defaults under `home`.
    public static func defaultTools(home: String = NSHomeDirectory()) -> [Tool] {
        func p(_ relative: String) -> String { (home as NSString).appendingPathComponent(relative) }
        return [
            Tool(id: "pnpm",
                 probe: .cli(executable: "/usr/bin/env", arguments: ["pnpm", "--version"]),
                 cachePath: p("Library/pnpm/store"),
                 reclaim: .cliCommand(executable: "/usr/bin/env", arguments: ["pnpm", "store", "prune"])),
            Tool(id: "npm",
                 probe: .cli(executable: "/usr/bin/env", arguments: ["npm", "--version"]),
                 cachePath: p(".npm"),
                 reclaim: .cliCommand(executable: "/usr/bin/env", arguments: ["npm", "cache", "clean", "--force"])),
            Tool(id: "uv",
                 probe: .cli(executable: "/usr/bin/env", arguments: ["uv", "--version"]),
                 cachePath: p(".cache/uv"),
                 reclaim: .cliCommand(executable: "/usr/bin/env", arguments: ["uv", "cache", "clean"])),
            Tool(id: "bun",
                 probe: .cli(executable: "/usr/bin/env", arguments: ["bun", "--version"]),
                 cachePath: p(".bun/install/cache"),
                 reclaim: .cliCommand(executable: "/usr/bin/env", arguments: ["bun", "pm", "cache", "rm"])),
            Tool(id: "gradle",
                 probe: .pathExists,
                 cachePath: p(".gradle/caches"),
                 reclaim: .deletePath(toTrash: false)),
        ]
    }
}
```

- [ ] **Step 4: 통과 확인**

Run: `cd DevSweep && swift test --filter packageCache`
Expected: PASS — 7 tests passed

- [ ] **Step 5: 커밋**

```bash
git add DevSweep/Sources/DevSweepCore/Detect/PackageCacheModule.swift \
        DevSweep/Tests/DevSweepCoreTests/PackageCacheModuleTests.swift
git commit -m "feat(devsweep): PackageCacheModule (CLI 우선 + gradle 경로폴백 M1 위임)"
```

---

### Task 8 (leaf C): NodeModulesModule

dev 루트 하위 `node_modules`/`.venv`/`venv` 후보 발행(전부 `.reviewNeeded`). 회수는 M1 `Reclaimer` 위임 → `ParentProjectActivitySignal`이 활성 프로젝트를 reclaim 시점 자동 `.protected` 강등(휴면 판정 재발명 없음). **pyiri 교훈의 node_modules판 회귀 테스트** 포함.

**Files:**
- Create: `DevSweep/Sources/DevSweepCore/Detect/NodeModulesModule.swift`
- Create: `DevSweep/Tests/DevSweepCoreTests/NodeModulesModuleTests.swift`

- [ ] **Step 1: 실패 테스트 작성** — `NodeModulesModuleTests.swift`

```swift
import Foundation
import Testing
@testable import DevSweepCore

private func emptyLayerReclaimer(_ deleter: any FileSystemDeleter) -> Reclaimer {
    Reclaimer(safety: SafetyLayer(signals: [], registry: ProtectedRegistry(userExcluded: [], systemProtected: [])),
              deleter: deleter)
}

@Test func nodeModulesScanFindsTargetsAndExcludesProtectedProjects() async {
    let tmp = TempDir(); defer { tmp.cleanup() }
    tmp.makeDir("alpha/node_modules")
    tmp.makeDir("beta/.venv")
    tmp.makeDir("gprecious-marketplace/node_modules")  // excluded by name
    let module = NodeModulesModule(roots: [tmp.url.path], reclaimer: emptyLayerReclaimer(RecordingDeleter()))
    let ids = Set(await module.scan().map { ($0.path! as NSString).lastPathComponent + "@" + (($0.path! as NSString).deletingLastPathComponent as NSString).lastPathComponent })
    #expect(ids.contains("node_modules@alpha"))
    #expect(ids.contains(".venv@beta"))
    #expect(!ids.contains("node_modules@gprecious-marketplace"))
}

@Test func nodeModulesDoesNotDescendIntoTargetDir() async {
    let tmp = TempDir(); defer { tmp.cleanup() }
    tmp.makeDir("proj/node_modules/nested/node_modules")  // nested must NOT be emitted
    let module = NodeModulesModule(roots: [tmp.url.path], reclaimer: emptyLayerReclaimer(RecordingDeleter()))
    let items = await module.scan()
    #expect(items.count == 1)
    #expect((items.first!.path! as NSString).lastPathComponent == "node_modules")
}

@Test func nodeModulesItemsAreReviewNeededDeletePath() async {
    let tmp = TempDir(); defer { tmp.cleanup() }
    tmp.makeDir("proj/node_modules")
    let module = NodeModulesModule(roots: [tmp.url.path], reclaimer: emptyLayerReclaimer(RecordingDeleter()))
    let item = await module.scan().first!
    #expect(item.safety == .reviewNeeded)
    #expect(item.reclaimMethod == .deletePath(toTrash: false))
}

@Test func nodeModulesReclaimDeletesWhenLayerHasNoSignals() async {
    let tmp = TempDir(); defer { tmp.cleanup() }
    tmp.makeDir("proj/node_modules")
    let deleter = RecordingDeleter(bytesPerCall: 8192)
    let module = NodeModulesModule(roots: [tmp.url.path], reclaimer: emptyLayerReclaimer(deleter))
    let outcomes = await module.reclaim(await module.scan(), dryRun: false)
    #expect(outcomes.first?.status == .deleted(bytes: 8192))
    #expect(await deleter.callCount == 1)
}

// M2 regression — the pyiri lesson applied to node_modules: an ACTIVE project (recent
// source) must be auto-protected at reclaim time by ParentProjectActivitySignal.
@Test func nodeModulesActiveProjectIsProtectedEndToEnd() async {
    let tmp = TempDir(); defer { tmp.cleanup() }
    tmp.makeDir("proj/node_modules")
    tmp.writeFile("proj/src/main.ts", "console.log(1)")  // recent source ⇒ active
    let deleter = RecordingDeleter(bytesPerCall: 8192)
    let projectLayer = DefaultSafetyLayer.make()  // includes ParentProjectActivitySignal + RecentUse
    let reclaimer = Reclaimer(safety: projectLayer, deleter: deleter)
    let module = NodeModulesModule(roots: [tmp.url.path], reclaimer: reclaimer)
    let outcomes = await module.reclaim(await module.scan(), dryRun: false)
    #expect(outcomes.first?.status == .skippedProtected)
    #expect(await deleter.callCount == 0)
}
```

- [ ] **Step 2: 실패 확인**

Run: `cd DevSweep && swift test --filter nodeModulesScanFindsTargetsAndExcludesProtectedProjects`
Expected: FAIL — build error: `cannot find 'NodeModulesModule' in scope`

- [ ] **Step 3: 구현** — `NodeModulesModule.swift`

```swift
import Foundation

/// Detects project dependency dirs (`node_modules`, `.venv`, `venv`) under configured dev
/// roots. Emits `.reviewNeeded` candidates only; it never decides dormancy itself —
/// reclaim delegates to the M1 Reclaimer, whose ParentProjectActivitySignal auto-protects
/// projects with recent source (the pyiri lesson, reused).
public struct NodeModulesModule: CleanupModule {
    public let id = "node-modules"
    public let displayName = "Project dependencies (node_modules, venv)"

    private let roots: [String]
    private let excludedProjectNames: Set<String>
    private let targetDirNames: Set<String>
    private let sizer: DirectorySizer
    private let fileManager: FileManager
    private let reclaimer: Reclaimer

    public init(
        roots: [String],
        reclaimer: Reclaimer,
        excludedProjectNames: Set<String> = ["gprecious-marketplace", "research-engine"],
        targetDirNames: Set<String> = ["node_modules", ".venv", "venv"],
        sizer: DirectorySizer = DirectorySizer(),
        fileManager: FileManager = .default
    ) {
        self.roots = roots
        self.reclaimer = reclaimer
        self.excludedProjectNames = excludedProjectNames
        self.targetDirNames = targetDirNames
        self.sizer = sizer
        self.fileManager = fileManager
    }

    public func isAvailable() async -> Bool {
        roots.contains { fileManager.fileExists(atPath: $0) }
    }

    public func scan() async -> [CleanupItem] {
        var items: [CleanupItem] = []
        for root in roots { collect(root, into: &items) }
        return items
    }

    private func collect(_ dir: String, into items: inout [CleanupItem]) {
        guard let entries = try? fileManager.contentsOfDirectory(atPath: dir) else { return }
        for entry in entries {
            let full = (dir as NSString).appendingPathComponent(entry)
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: full, isDirectory: &isDir), isDir.boolValue else { continue }

            if targetDirNames.contains(entry) {
                // Skip when the owning project (immediate parent dir) is excluded.
                let projectName = (dir as NSString).lastPathComponent
                if excludedProjectNames.contains(projectName) { continue }
                items.append(CleanupItem(
                    id: full,
                    path: full,
                    sizeBytes: sizer.size(of: full),
                    lastUsed: nil,
                    safety: .reviewNeeded,
                    reclaimMethod: .deletePath(toTrash: false)
                ))
                // Do NOT descend into a target dir.
            } else if entry == ".git" {
                continue
            } else {
                collect(full, into: &items)
            }
        }
    }

    public func reclaim(_ items: [CleanupItem], dryRun: Bool) async -> [ReclaimOutcome] {
        await reclaimer.reclaim(items, dryRun: dryRun)
    }
}
```

- [ ] **Step 4: 통과 확인**

Run: `cd DevSweep && swift test --filter nodeModules`
Expected: PASS — 5 tests passed

- [ ] **Step 5: 커밋**

```bash
git add DevSweep/Sources/DevSweepCore/Detect/NodeModulesModule.swift \
        DevSweep/Tests/DevSweepCoreTests/NodeModulesModuleTests.swift
git commit -m "feat(devsweep): NodeModulesModule (M1 Reclaimer 위임 + 활성 프로젝트 보호 회귀)"
```

---

### Phase 2 머지 (orchestrator)

- [ ] leaf 워크트리들을 foundation 분기점 위로 머지. 머지 전 겹침 확인:

```bash
# 각 leaf 브랜치가 건드린 파일이 disjoint한지 확인 (출력 비어야 정상)
comm -12 <(git diff --name-only HEAD wt/A | sort) <(git diff --name-only HEAD wt/B | sort)
comm -12 <(git diff --name-only HEAD wt/A | sort) <(git diff --name-only HEAD wt/C | sort)
comm -12 <(git diff --name-only HEAD wt/B | sort) <(git diff --name-only HEAD wt/C | sort)
git merge --no-ff wt/A wt/B wt/C   # 또는 순차 머지
cd DevSweep && swift test          # 머지 직후 전체 게이트
```
Expected: 겹침 0, 머지 충돌 0, 전체 테스트 green.

---

## Phase 3 — Integration (Task 9–10)

### Task 9: DefaultDetectorRegistry 팩토리 + 레지스트리 통합 테스트

프로덕션 조립. **캐시용 안전계층(참조 신호만, recency 제외)과 프로젝트용 안전계층(recency 포함)을 분리** — 캐시는 최근 사용이 정상이므로 RecentUse로 보호하면 안 되고, node_modules는 활성 프로젝트를 recency로 보호해야 한다. (spec §3 "경로 삭제는 M1 Reclaimer 경유"를 유지하되, 주입하는 SafetyLayer 조합을 용도별로 다르게.)

**Files:**
- Create: `DevSweep/Sources/DevSweepCore/Detect/DefaultDetectorRegistry.swift`
- Create: `DevSweep/Tests/DevSweepCoreTests/DefaultDetectorRegistryTests.swift`

- [ ] **Step 1: 실패 테스트 작성** — `DefaultDetectorRegistryTests.swift`

```swift
import Foundation
import Testing
@testable import DevSweepCore

@Test func defaultRegistryComposesThreeRealModuleTypesDeterministically() async {
    // Docker unavailable (df exit 1), no package tools available, no dev roots → empty scan,
    // but the registry is built from the real module types without crashing.
    let runner = ScriptedCommandRunner([
        "/usr/bin/env docker system df": [.init(exitCode: 1)]
    ])
    let registry = DefaultDetectorRegistry.make(
        home: "/nonexistent-home",
        devRoots: [],
        commandRunner: runner,
        deleter: RecordingDeleter()
    )
    #expect(await registry.scanAll().isEmpty)
}

@Test func defaultRegistrySurfacesAvailableDockerOnly() async {
    let df = """
    {"Type":"Build Cache","TotalCount":"5","Active":"0","Size":"2GB","Reclaimable":"2GB"}
    """
    let runner = ScriptedCommandRunner([
        "/usr/bin/env docker system df": [.init(exitCode: 0)],
        "/usr/bin/env docker system df --format {{json .}}": [.init(stdout: df)]
    ])
    let registry = DefaultDetectorRegistry.make(
        home: "/nonexistent-home",
        devRoots: [],
        commandRunner: runner,
        deleter: RecordingDeleter()
    )
    let grouped = await registry.scanGrouped()
    #expect(grouped.map(\.module) == ["docker"])
    #expect(grouped.first?.items.contains { $0.id == "docker:build-cache" } == true)
}
```

- [ ] **Step 2: 실패 확인**

Run: `cd DevSweep && swift test --filter defaultRegistryComposesThreeRealModuleTypesDeterministically`
Expected: FAIL — build error: `cannot find 'DefaultDetectorRegistry' in scope`

- [ ] **Step 3: 구현** — `DefaultDetectorRegistry.swift`

```swift
import Foundation

/// Composes the production DetectorRegistry. Caches and projects get DIFFERENT safety
/// compositions on purpose:
///   • cacheLayer  — reference signals only (process/launchd/crontab). NO recency:
///                   caches are *expected* to be recently used; recency must not protect them.
///   • projectLayer — full DefaultSafetyLayer (recency-aware) so ACTIVE projects with
///                    recent source are protected (the pyiri/node_modules lesson).
public enum DefaultDetectorRegistry {
    public static func make(
        home: String = NSHomeDirectory(),
        devRoots: [String] = [(("~/Documents/dev") as NSString).expandingTildeInPath],
        commandRunner: any CommandRunner = ProcessCommandRunner(),
        deleter: any FileSystemDeleter,
        registry: ProtectedRegistry = ProtectedRegistry()
    ) -> DetectorRegistry {
        let sizer = DirectorySizer()

        let cacheLayer = SafetyLayer(
            signals: [
                ProcessReferenceSignal(runner: commandRunner),
                LaunchdReferenceSignal(),
                CrontabReferenceSignal(runner: commandRunner)
            ],
            registry: registry
        )
        let projectLayer = DefaultSafetyLayer.make(commandRunner: commandRunner, registry: registry)

        let cacheReclaimer = Reclaimer(safety: cacheLayer, deleter: deleter)
        let projectReclaimer = Reclaimer(safety: projectLayer, deleter: deleter)

        let docker = DockerModule(runner: commandRunner)
        let packageCache = PackageCacheModule(
            tools: PackageCacheModule.defaultTools(home: home),
            runner: commandRunner,
            reclaimer: cacheReclaimer,
            sizer: sizer
        )
        let nodeModules = NodeModulesModule(
            roots: devRoots,
            reclaimer: projectReclaimer,
            sizer: sizer
        )

        return DetectorRegistry(modules: [docker, packageCache, nodeModules])
    }
}
```

- [ ] **Step 4: 통과 확인**

Run: `cd DevSweep && swift test --filter defaultRegistry`
Expected: PASS — 2 tests passed

- [ ] **Step 5: 커밋**

```bash
git add DevSweep/Sources/DevSweepCore/Detect/DefaultDetectorRegistry.swift \
        DevSweep/Tests/DevSweepCoreTests/DefaultDetectorRegistryTests.swift
git commit -m "feat(devsweep): DefaultDetectorRegistry 팩토리 (cache vs project 안전계층 분리)"
```

---

### Task 10: 전체 회귀 게이트

M2가 M1 안전 경로를 바꾸지 않았음을 전체 스위트로 증명. pyiri 회귀 보존 + 신규 M2 테스트 전부 green.

**Files:** (없음 — 검증·확인 단계)

- [ ] **Step 1: 전체 테스트 실행 (orchestrator ground truth)**

Run: `cd DevSweep && swift test`
Expected: PASS — M1 33 + M2 신규 전부 green, 실패 0.

- [ ] **Step 2: M1 핵심 회귀 명시 확인**

Run: `cd DevSweep && swift test --filter pyiri`
Expected: PASS — `defaultSafetyLayerProtectsPyiriEndToEnd` / `pyiriScenarioIsProtectedByMultipleSignals` 등 M1 pyiri 회귀 그대로 green.

- [ ] **Step 3: 빌드 경고 0 확인**

Run: `cd DevSweep && swift build 2>&1 | grep -i warning || echo "no warnings"`
Expected: `no warnings`

- [ ] **Step 4: 최종 커밋 (필요 시)**

```bash
git add -A && git commit -m "test(devsweep): M2 Detector 전체 회귀 게이트 통과" --allow-empty
```

---

## Self-Review

**1. Spec coverage:**

| Spec 항목 | 구현 Task |
|---|---|
| CleanupModule 프로토콜(scan+reclaim) | Task 4 |
| CommandRunner runResult + CommandResult, run() 하위호환 | Task 1 |
| DirectorySizer du, 심링크 미추적 | Task 3 |
| DetectorRegistry 병렬 scanAll + 미가용 skip | Task 5 |
| DockerModule 안전등급 차등(builder/dangling autoSafe, image -a reviewNeeded), --volumes 금지, before/after 실측 | Task 6 |
| PackageCacheModule CLI 우선 + gradle 경로폴백(M1 Reclaimer) | Task 7 |
| NodeModulesModule 후보 발행 + M1 Reclaimer 위임 + ParentProject 자동 보호 | Task 8 |
| 경로 삭제 전부 M1 Reclaimer 경유 | Task 7(gradle)·8(node) |
| CLI 회수는 종료코드 판정 | Task 6·7 |
| pyiri 교훈 회귀(node_modules판) | Task 8 `nodeModulesActiveProjectIsProtectedEndToEnd` |
| 테스트 더블 재사용 + MockCommandRunner runResult 확장 | Task 1·2·4 |
| 비범위(증분 캐싱 M3 / reclaim 라우팅 M4) | 계획 미포함 (의도적) |

신규 발견(spec 보강): 캐시 vs 프로젝트 **안전계층 분리**(Task 9). spec §3은 "전부 M1 Reclaimer 경유"였으나, 캐시에 RecentUse를 적용하면 정상 캐시가 보호돼 회수 불가가 되는 문제 → 주입 SafetyLayer 조합을 용도별로 다르게 해결. M1 Reclaimer 경유 원칙은 유지.

**2. Placeholder scan:** TBD/TODO/"handle edge cases" 류 없음. 모든 코드 스텝에 완전한 코드 + 정확한 명령/기대 출력 포함.

**3. Type consistency:** M1 실제 시그니처와 대조 완료 — `CleanupItem(id:path:sizeBytes:lastUsed:safety:reclaimMethod:)`, `ReclaimMethod.deletePath(toTrash:)`/`.cliCommand(executable:arguments:)`, `ReclaimStatus.skippedProtected/.dryRun(plannedBytes:)/.deleted(bytes:)/.failed(message:)`, `Reclaimer(safety:deleter:).reclaim(_:dryRun:)`, `SafetyLayer(signals:registry:)`, `ProtectedRegistry(userExcluded:systemProtected:)`, `DefaultSafetyLayer.make(commandRunner:registry:)`, `ProcessReferenceSignal(runner:)`/`CrontabReferenceSignal(runner:)`/`LaunchdReferenceSignal()`, `RecordingDeleter(bytesPerCall:)` actor, `TempDir.makeDir/.writeFile/.url/.cleanup` 전부 일치 확인.

---

## Execution Handoff

Plan complete. 실행은 [[herdr-worktree-parallel]] 3단계로 orchestrator(claude)가 조율, worker(claude+codex)가 leaf 병렬 구현. 완료 판정은 orchestrator의 직접 `swift test`.
