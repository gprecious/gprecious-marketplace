# DevSweep Safety Layer (Milestone 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the safety-critical core of DevSweep — the Safety Layer that classifies cleanup candidates, runs the multi-signal "active-check" that prevents deleting in-use resources (the pyiri defense), and guarantees scan/dry-run never deletes — as a fully unit-tested Swift package with no UI.

**Architecture:** A standalone Swift Package (`DevSweep/`, library `DevSweepCore`) holding pure logic: core models (`CleanupItem`, `SafetyClass`, `ReclaimMethod`), a `SafetyLayer` that runs a 3-gate evaluation pipeline (protected-registry → active-check signals → classification), a set of injectable `ActivitySignal` implementations (process/launchd/crontab/recent-use/parent-project), a `FileSystemDeleter` abstraction so real deletion is never touched in tests, and a `Reclaimer` whose dry-run path provably never calls the deleter. Everything is dependency-injected (command runner, file manager, clock) so it is deterministic under test. The menu-bar app, detectors, store, and StoreKit are later milestones that consume this core.

**Tech Stack:** Swift 6 (strict concurrency), Swift Package Manager, Swift Testing (`import Testing`, `@Test`, `#expect`). macOS 14+. No third-party dependencies.

---

## File Structure

New package under the repo at `DevSweep/`:

```
DevSweep/
├── Package.swift
├── Sources/DevSweepCore/
│   ├── Models/
│   │   ├── SafetyClass.swift           # autoSafe / reviewNeeded / protected
│   │   ├── ReclaimMethod.swift         # deletePath(toTrash:) / cliCommand(...)
│   │   └── CleanupItem.swift           # candidate: id, path?, size, lastUsed, safety, method
│   ├── Safety/
│   │   ├── ActivitySignal.swift        # protocol: name + isActive(path:) async
│   │   ├── ProtectedRegistry.swift     # user-excluded + system-protected prefixes
│   │   ├── SafetyEvaluation.swift      # result: (possibly downgraded) item + downgradedBy
│   │   ├── SafetyLayer.swift           # the 3-gate evaluate() pipeline
│   │   ├── ProcessReferenceSignal.swift
│   │   ├── LaunchdReferenceSignal.swift
│   │   ├── CrontabReferenceSignal.swift
│   │   ├── RecentUseSignal.swift
│   │   ├── ParentProjectActivitySignal.swift
│   │   └── DefaultSafetyLayer.swift    # factory composing the real signals
│   ├── FileSystem/
│   │   ├── FileSystemDeleter.swift     # protocol: delete(path:toTrash:) async throws -> Int64
│   │   └── TrashDeleter.swift          # real impl (FileManager.trashItem / removeItem)
│   ├── Process/
│   │   ├── CommandRunner.swift         # protocol: run(executable, args) async throws -> stdout
│   │   └── ProcessCommandRunner.swift  # real impl (Foundation.Process)
│   └── Reclaim/
│       ├── ReclaimOutcome.swift        # status enum + outcome struct
│       └── Reclaimer.swift             # evaluate → (dryRun ? plan : delete); never deletes protected
└── Tests/DevSweepCoreTests/
    ├── Support/
    │   ├── TempDir.swift               # make/cleanup temp fixture dirs
    │   ├── MockActivitySignal.swift
    │   ├── MockCommandRunner.swift
    │   └── RecordingDeleter.swift      # records delete() calls, deletes nothing
    ├── ScaffoldTests.swift
    ├── ModelsTests.swift
    ├── ProtectedRegistryTests.swift
    ├── SafetyLayerTests.swift          # includes the pyiri regression
    ├── ReclaimerTests.swift            # dry-run invariant + protected-skip invariant
    ├── ProcessReferenceSignalTests.swift
    ├── LaunchdReferenceSignalTests.swift
    ├── CrontabReferenceSignalTests.swift
    ├── RecentUseSignalTests.swift
    ├── ParentProjectActivitySignalTests.swift
    └── DefaultSafetyLayerPyiriTests.swift   # capstone: real signals reproduce pyiri
```

All work happens on the current branch `design/devsweep-menubar-cleaner` (or a fresh feature branch if you prefer; commits below assume the current branch).

---

### Task 0: Package scaffold

**Files:**
- Create: `DevSweep/Package.swift`
- Create: `DevSweep/Sources/DevSweepCore/DevSweepCore.swift`
- Test: `DevSweep/Tests/DevSweepCoreTests/ScaffoldTests.swift`

- [ ] **Step 1: Write the failing test**

Create `DevSweep/Tests/DevSweepCoreTests/ScaffoldTests.swift`:

```swift
import Testing
@testable import DevSweepCore

@Test func packageVersionIsExposed() {
    #expect(DevSweepCore.version == "0.0.1")
}
```

- [ ] **Step 2: Create the package manifest and an empty source so the test target resolves**

Create `DevSweep/Package.swift`:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DevSweep",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "DevSweepCore", targets: ["DevSweepCore"])
    ],
    targets: [
        .target(name: "DevSweepCore"),
        .testTarget(name: "DevSweepCoreTests", dependencies: ["DevSweepCore"])
    ]
)
```

Create `DevSweep/Sources/DevSweepCore/DevSweepCore.swift`:

```swift
/// Namespace for package-level metadata.
public enum DevSweepCore {
    /// Semantic version of the core package.
    public static let version = "0.0.1"
}
```

- [ ] **Step 3: Run the test to verify it passes**

Run: `cd DevSweep && swift test --filter packageVersionIsExposed`
Expected: build succeeds, 1 test passing.

- [ ] **Step 4: Add a .gitignore for Swift build artifacts**

Create `DevSweep/.gitignore`:

```
.build/
.swiftpm/
*.xcodeproj
DerivedData/
```

- [ ] **Step 5: Commit**

```bash
git add DevSweep/Package.swift DevSweep/Sources DevSweep/Tests DevSweep/.gitignore
git commit -m "feat(devsweep): scaffold DevSweepCore Swift package"
```

---

### Task 1: Core models — SafetyClass, ReclaimMethod, CleanupItem

**Files:**
- Create: `DevSweep/Sources/DevSweepCore/Models/SafetyClass.swift`
- Create: `DevSweep/Sources/DevSweepCore/Models/ReclaimMethod.swift`
- Create: `DevSweep/Sources/DevSweepCore/Models/CleanupItem.swift`
- Test: `DevSweep/Tests/DevSweepCoreTests/ModelsTests.swift`

- [ ] **Step 1: Write the failing test**

Create `DevSweep/Tests/DevSweepCoreTests/ModelsTests.swift`:

```swift
import Testing
@testable import DevSweepCore

@Test func cleanupItemSafetyIsMutableForDowngrade() {
    var item = CleanupItem(
        id: "npm-cache",
        path: "/Users/x/.npm",
        sizeBytes: 9_300_000_000,
        lastUsed: nil,
        safety: .autoSafe,
        reclaimMethod: .deletePath(toTrash: false)
    )
    item.safety = .protected
    #expect(item.safety == .protected)
}

@Test func reclaimMethodEquatable() {
    #expect(ReclaimMethod.deletePath(toTrash: true) == .deletePath(toTrash: true))
    #expect(ReclaimMethod.deletePath(toTrash: true) != .deletePath(toTrash: false))
    #expect(
        ReclaimMethod.cliCommand(executable: "docker", arguments: ["builder", "prune"])
        == .cliCommand(executable: "docker", arguments: ["builder", "prune"])
    )
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd DevSweep && swift test --filter ModelsTests`
Expected: FAIL — "cannot find 'CleanupItem' / 'ReclaimMethod' in scope".

- [ ] **Step 3: Write minimal implementation**

Create `DevSweep/Sources/DevSweepCore/Models/SafetyClass.swift`:

```swift
/// How dangerous it is to reclaim a candidate.
public enum SafetyClass: Sendable, Equatable {
    /// Pure cache the owning tool regenerates. May be auto-cleaned only when the
    /// user has explicitly opted that category into automatic cleanup.
    case autoSafe
    /// Reclaimable but has a re-cost (e.g. node_modules). Always requires explicit approval.
    case reviewNeeded
    /// Never touched. Not even shown as a candidate.
    case protected
}
```

Create `DevSweep/Sources/DevSweepCore/Models/ReclaimMethod.swift`:

```swift
/// How a candidate is reclaimed.
public enum ReclaimMethod: Sendable, Equatable {
    /// Delete a filesystem path. `toTrash` moves to Trash instead of permanent removal.
    case deletePath(toTrash: Bool)
    /// Invoke a tool's own CLI (state-aware reclaim), e.g. `docker builder prune`.
    case cliCommand(executable: String, arguments: [String])
}
```

Create `DevSweep/Sources/DevSweepCore/Models/CleanupItem.swift`:

```swift
import Foundation

/// A single reclaim candidate produced by a detector module. `scan()` never deletes;
/// it only describes what *could* be reclaimed.
public struct CleanupItem: Sendable, Equatable, Identifiable {
    /// Stable identity (path for path-based items, or "module:key" for CLI-based ones).
    public let id: String
    /// Filesystem path. `nil` for CLI-based reclaim (e.g. docker build cache).
    public let path: String?
    public let sizeBytes: Int64
    /// Last-used timestamp if known (used by recency checks). `nil` if unknown.
    public let lastUsed: Date?
    /// Mutable so the Safety Layer can downgrade a candidate to `.protected`.
    public var safety: SafetyClass
    public let reclaimMethod: ReclaimMethod

    public init(
        id: String,
        path: String?,
        sizeBytes: Int64,
        lastUsed: Date?,
        safety: SafetyClass,
        reclaimMethod: ReclaimMethod
    ) {
        self.id = id
        self.path = path
        self.sizeBytes = sizeBytes
        self.lastUsed = lastUsed
        self.safety = safety
        self.reclaimMethod = reclaimMethod
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd DevSweep && swift test --filter ModelsTests`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add DevSweep/Sources/DevSweepCore/Models DevSweep/Tests/DevSweepCoreTests/ModelsTests.swift
git commit -m "feat(devsweep): core models — SafetyClass, ReclaimMethod, CleanupItem"
```

---

### Task 2: ProtectedRegistry (Gate ③)

**Files:**
- Create: `DevSweep/Sources/DevSweepCore/Safety/ProtectedRegistry.swift`
- Test: `DevSweep/Tests/DevSweepCoreTests/ProtectedRegistryTests.swift`

- [ ] **Step 1: Write the failing test**

Create `DevSweep/Tests/DevSweepCoreTests/ProtectedRegistryTests.swift`:

```swift
import Foundation
import Testing
@testable import DevSweepCore

@Test func systemProtectedPrefixMatchesNestedPath() {
    let registry = ProtectedRegistry(
        userExcluded: [],
        systemProtected: ["/Users/x/.ssh", "/Users/x/Library/Keychains"]
    )
    #expect(registry.isProtected(path: "/Users/x/.ssh/id_rsa") == true)
    #expect(registry.isProtected(path: "/Users/x/Library/Keychains/login.keychain-db") == true)
    #expect(registry.isProtected(path: "/Users/x/.npm") == false)
}

@Test func userExcludedExactPathIsProtected() {
    let registry = ProtectedRegistry(userExcluded: ["/Users/x/work/keep-me"], systemProtected: [])
    #expect(registry.isProtected(path: "/Users/x/work/keep-me") == true)
    #expect(registry.isProtected(path: "/Users/x/work/keep-me-not") == false)
}

@Test func nilPathIsNotProtected() {
    let registry = ProtectedRegistry(userExcluded: [], systemProtected: [])
    #expect(registry.isProtected(path: nil) == false)
}

@Test func tildePrefixesAreExpanded() {
    // defaultSystemProtected uses ~-prefixed entries; they must expand before matching.
    let home = NSHomeDirectory()
    let registry = ProtectedRegistry()  // uses defaults
    #expect(registry.isProtected(path: "\(home)/.ssh/config") == true)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd DevSweep && swift test --filter ProtectedRegistryTests`
Expected: FAIL — "cannot find 'ProtectedRegistry' in scope".

- [ ] **Step 3: Write minimal implementation**

Create `DevSweep/Sources/DevSweepCore/Safety/ProtectedRegistry.swift`:

```swift
import Foundation

/// Gate ③ of the Safety Layer: an absolute deny-list. A path that matches here is
/// `.protected` no matter what any other gate says. Holds user-chosen permanent
/// exclusions (exact paths) plus built-in system-protected prefixes.
public struct ProtectedRegistry: Sendable {
    private let userExcluded: Set<String>
    private let systemProtected: [String]

    public init(
        userExcluded: Set<String> = [],
        systemProtected: [String] = ProtectedRegistry.defaultSystemProtected
    ) {
        self.userExcluded = userExcluded
        self.systemProtected = systemProtected.map { ($0 as NSString).expandingTildeInPath }
    }

    /// True if the path is permanently protected. `nil` paths (CLI-based items) are never protected here.
    public func isProtected(path: String?) -> Bool {
        guard let path else { return false }
        if userExcluded.contains(path) { return true }
        for prefix in systemProtected where path == prefix || path.hasPrefix(prefix + "/") {
            return true
        }
        return false
    }

    /// Built-in protected prefixes. `~` is expanded at init time.
    public static let defaultSystemProtected: [String] = [
        "~/.ssh",
        "~/Library/Keychains",
        "~/.gnupg",
        "~/.config/gh/hosts.yml"
    ]
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd DevSweep && swift test --filter ProtectedRegistryTests`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add DevSweep/Sources/DevSweepCore/Safety/ProtectedRegistry.swift DevSweep/Tests/DevSweepCoreTests/ProtectedRegistryTests.swift
git commit -m "feat(devsweep): ProtectedRegistry — Safety Layer gate 3"
```

---

### Task 3: ActivitySignal protocol + test double

**Files:**
- Create: `DevSweep/Sources/DevSweepCore/Safety/ActivitySignal.swift`
- Create: `DevSweep/Tests/DevSweepCoreTests/Support/MockActivitySignal.swift`
- Test: (covered in Task 4; this task adds a tiny self-test of the mock)
- Test: `DevSweep/Tests/DevSweepCoreTests/Support/MockActivitySignal.swift` self-check via `ActivitySignalMockTests`

- [ ] **Step 1: Write the failing test**

Append to a new file `DevSweep/Tests/DevSweepCoreTests/Support/MockActivitySignal.swift`:

```swift
import Testing
@testable import DevSweepCore

/// Test double for ActivitySignal: reports active only for paths in `activePaths`.
struct MockActivitySignal: ActivitySignal {
    let name: String
    let activePaths: Set<String>

    func isActive(path: String) async -> Bool {
        activePaths.contains(path)
    }
}

@Test func mockActivitySignalReportsConfiguredPaths() async {
    let signal = MockActivitySignal(name: "test", activePaths: ["/a"])
    #expect(await signal.isActive(path: "/a") == true)
    #expect(await signal.isActive(path: "/b") == false)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd DevSweep && swift test --filter mockActivitySignalReportsConfiguredPaths`
Expected: FAIL — "cannot find type 'ActivitySignal' in scope".

- [ ] **Step 3: Write minimal implementation**

Create `DevSweep/Sources/DevSweepCore/Safety/ActivitySignal.swift`:

```swift
/// Gate ② building block: one heuristic that answers "does this path look in use right now?"
/// Implementations are injected so the Safety Layer is deterministic under test.
public protocol ActivitySignal: Sendable {
    /// Human-readable name, recorded in `SafetyEvaluation.downgradedBy`.
    var name: String { get }
    /// True if this signal considers `path` actively in use.
    func isActive(path: String) async -> Bool
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd DevSweep && swift test --filter mockActivitySignalReportsConfiguredPaths`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add DevSweep/Sources/DevSweepCore/Safety/ActivitySignal.swift DevSweep/Tests/DevSweepCoreTests/Support/MockActivitySignal.swift
git commit -m "feat(devsweep): ActivitySignal protocol + mock"
```

---

### Task 4: SafetyLayer evaluate pipeline + pyiri regression

**Files:**
- Create: `DevSweep/Sources/DevSweepCore/Safety/SafetyEvaluation.swift`
- Create: `DevSweep/Sources/DevSweepCore/Safety/SafetyLayer.swift`
- Test: `DevSweep/Tests/DevSweepCoreTests/SafetyLayerTests.swift`

- [ ] **Step 1: Write the failing test**

Create `DevSweep/Tests/DevSweepCoreTests/SafetyLayerTests.swift`:

```swift
import Foundation
import Testing
@testable import DevSweepCore

private func candidate(_ path: String, _ safety: SafetyClass = .reviewNeeded) -> CleanupItem {
    CleanupItem(id: path, path: path, sizeBytes: 4_700_000_000, lastUsed: nil,
                safety: safety, reclaimMethod: .deletePath(toTrash: false))
}

@Test func noSignalsKeepsOriginalClassification() async {
    let layer = SafetyLayer(signals: [], registry: ProtectedRegistry(userExcluded: [], systemProtected: []))
    let eval = await layer.evaluate(candidate("/Users/x/.npm", .autoSafe))
    #expect(eval.item.safety == .autoSafe)
    #expect(eval.downgradedBy.isEmpty)
}

@Test func protectedRegistryForcesProtection() async {
    let layer = SafetyLayer(
        signals: [MockActivitySignal(name: "process", activePaths: [])],
        registry: ProtectedRegistry(userExcluded: ["/Users/x/.ssh"], systemProtected: [])
    )
    let eval = await layer.evaluate(candidate("/Users/x/.ssh"))
    #expect(eval.item.safety == .protected)
    #expect(eval.downgradedBy == ["protected-registry"])
}

@Test func anyActiveSignalDowngradesToProtected() async {
    let layer = SafetyLayer(
        signals: [MockActivitySignal(name: "process", activePaths: ["/Users/x/app"])],
        registry: ProtectedRegistry(userExcluded: [], systemProtected: [])
    )
    let eval = await layer.evaluate(candidate("/Users/x/app"))
    #expect(eval.item.safety == .protected)
    #expect(eval.downgradedBy == ["process"])
}

/// THE pyiri REGRESSION. A 4.7GB candidate that three independent signals report as
/// active (process on port, launchd KeepAlive, crontab reference) MUST be downgraded
/// to .protected and never offered for deletion. If this test ever fails, the build fails.
@Test func pyiriScenarioIsProtectedByMultipleSignals() async {
    let pyiri = "/Users/x/.openclaw-pyiri"
    let layer = SafetyLayer(
        signals: [
            MockActivitySignal(name: "process", activePaths: [pyiri]),
            MockActivitySignal(name: "launchd", activePaths: [pyiri]),
            MockActivitySignal(name: "crontab", activePaths: [pyiri]),
            MockActivitySignal(name: "recent-use", activePaths: [pyiri]),
            MockActivitySignal(name: "parent-project", activePaths: [])
        ],
        registry: ProtectedRegistry(userExcluded: [], systemProtected: [])
    )
    let eval = await layer.evaluate(candidate(pyiri, .reviewNeeded))
    #expect(eval.item.safety == .protected)
    #expect(eval.downgradedBy.contains("process"))
    #expect(eval.downgradedBy.contains("launchd"))
    #expect(eval.downgradedBy.contains("crontab"))
}

@Test func nilPathItemSkipsActiveCheck() async {
    // CLI-based items (path == nil) have no filesystem path to check; they keep classification.
    let layer = SafetyLayer(
        signals: [MockActivitySignal(name: "process", activePaths: [])],
        registry: ProtectedRegistry(userExcluded: [], systemProtected: [])
    )
    let cli = CleanupItem(id: "docker:buildcache", path: nil, sizeBytes: 14_000_000_000,
                          lastUsed: nil, safety: .autoSafe,
                          reclaimMethod: .cliCommand(executable: "docker", arguments: ["builder", "prune", "-a", "-f"]))
    let eval = await layer.evaluate(cli)
    #expect(eval.item.safety == .autoSafe)
    #expect(eval.downgradedBy.isEmpty)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd DevSweep && swift test --filter SafetyLayerTests`
Expected: FAIL — "cannot find 'SafetyLayer' / 'SafetyEvaluation' in scope".

- [ ] **Step 3: Write minimal implementation**

Create `DevSweep/Sources/DevSweepCore/Safety/SafetyEvaluation.swift`:

```swift
/// Result of running the Safety Layer on one candidate.
public struct SafetyEvaluation: Sendable, Equatable {
    /// The candidate after evaluation. `safety` is `.protected` if any gate forced it.
    public let item: CleanupItem
    /// Names of the gates/signals that forced protection. Empty if classification was kept.
    public let downgradedBy: [String]

    public init(item: CleanupItem, downgradedBy: [String]) {
        self.item = item
        self.downgradedBy = downgradedBy
    }
}
```

Create `DevSweep/Sources/DevSweepCore/Safety/SafetyLayer.swift`:

```swift
/// The single gate every deletion passes through. `evaluate` runs gates in order:
///   ③ protected-registry (absolute deny) → ② active-check signals → ① keep classification.
/// `evaluate` NEVER deletes anything; it only decides whether a candidate is allowed.
public struct SafetyLayer: Sendable {
    private let signals: [any ActivitySignal]
    private let registry: ProtectedRegistry

    public init(signals: [any ActivitySignal], registry: ProtectedRegistry) {
        self.signals = signals
        self.registry = registry
    }

    public func evaluate(_ item: CleanupItem) async -> SafetyEvaluation {
        // Gate ③ — protected registry is absolute.
        if registry.isProtected(path: item.path) {
            var downgraded = item
            downgraded.safety = .protected
            return SafetyEvaluation(item: downgraded, downgradedBy: ["protected-registry"])
        }

        // Gate ② — active-check signals (only meaningful for path-bearing items).
        var fired: [String] = []
        if let path = item.path {
            for signal in signals where await signal.isActive(path: path) {
                fired.append(signal.name)
            }
        }
        if !fired.isEmpty {
            var downgraded = item
            downgraded.safety = .protected
            return SafetyEvaluation(item: downgraded, downgradedBy: fired)
        }

        // Gate ① — no downgrade; keep the detector's original classification.
        return SafetyEvaluation(item: item, downgradedBy: [])
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd DevSweep && swift test --filter SafetyLayerTests`
Expected: PASS (5 tests, including `pyiriScenarioIsProtectedByMultipleSignals`).

- [ ] **Step 5: Commit**

```bash
git add DevSweep/Sources/DevSweepCore/Safety/SafetyEvaluation.swift DevSweep/Sources/DevSweepCore/Safety/SafetyLayer.swift DevSweep/Tests/DevSweepCoreTests/SafetyLayerTests.swift
git commit -m "feat(devsweep): SafetyLayer evaluate pipeline + pyiri regression test"
```

---

### Task 5: FileSystemDeleter abstraction + recording double

**Files:**
- Create: `DevSweep/Sources/DevSweepCore/FileSystem/FileSystemDeleter.swift`
- Create: `DevSweep/Tests/DevSweepCoreTests/Support/RecordingDeleter.swift`
- Test: `DevSweep/Tests/DevSweepCoreTests/Support/RecordingDeleter.swift` self-check via `RecordingDeleterTests`

- [ ] **Step 1: Write the failing test**

Create `DevSweep/Tests/DevSweepCoreTests/Support/RecordingDeleter.swift`:

```swift
import Foundation
import Testing
@testable import DevSweepCore

/// Test double for FileSystemDeleter. Records every call and DELETES NOTHING.
/// Returns the configured byte count so callers can assert reclaim accounting.
actor RecordingDeleter: FileSystemDeleter {
    struct Call: Equatable { let path: String; let toTrash: Bool }
    private(set) var calls: [Call] = []
    private let bytesPerCall: Int64

    init(bytesPerCall: Int64 = 0) { self.bytesPerCall = bytesPerCall }

    func delete(path: String, toTrash: Bool) async throws -> Int64 {
        calls.append(Call(path: path, toTrash: toTrash))
        return bytesPerCall
    }

    var callCount: Int { calls.count }
}

@Test func recordingDeleterRecordsAndDeletesNothing() async throws {
    let deleter = RecordingDeleter(bytesPerCall: 100)
    let bytes = try await deleter.delete(path: "/tmp/x", toTrash: true)
    #expect(bytes == 100)
    #expect(await deleter.callCount == 1)
    #expect(await deleter.calls.first == .init(path: "/tmp/x", toTrash: true))
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd DevSweep && swift test --filter recordingDeleterRecordsAndDeletesNothing`
Expected: FAIL — "cannot find type 'FileSystemDeleter' in scope".

- [ ] **Step 3: Write minimal implementation**

Create `DevSweep/Sources/DevSweepCore/FileSystem/FileSystemDeleter.swift`:

```swift
/// Abstraction over real deletion so destructive operations are isolated behind an
/// interface. Tests inject a recording double; nothing in the test suite ever removes files.
public protocol FileSystemDeleter: Sendable {
    /// Delete `path` (to Trash if `toTrash`). Returns the number of bytes reclaimed.
    func delete(path: String, toTrash: Bool) async throws -> Int64
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd DevSweep && swift test --filter recordingDeleterRecordsAndDeletesNothing`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add DevSweep/Sources/DevSweepCore/FileSystem/FileSystemDeleter.swift DevSweep/Tests/DevSweepCoreTests/Support/RecordingDeleter.swift
git commit -m "feat(devsweep): FileSystemDeleter abstraction + recording test double"
```

---

### Task 6: Reclaimer — dry-run invariant + protected-skip invariant

**Files:**
- Create: `DevSweep/Sources/DevSweepCore/Reclaim/ReclaimOutcome.swift`
- Create: `DevSweep/Sources/DevSweepCore/Reclaim/Reclaimer.swift`
- Test: `DevSweep/Tests/DevSweepCoreTests/ReclaimerTests.swift`

- [ ] **Step 1: Write the failing test**

Create `DevSweep/Tests/DevSweepCoreTests/ReclaimerTests.swift`:

```swift
import Foundation
import Testing
@testable import DevSweepCore

private func pathItem(_ path: String, _ safety: SafetyClass = .reviewNeeded) -> CleanupItem {
    CleanupItem(id: path, path: path, sizeBytes: 1_000, lastUsed: nil,
                safety: safety, reclaimMethod: .deletePath(toTrash: false))
}

@Test func dryRunNeverCallsDeleter() async {
    let deleter = RecordingDeleter(bytesPerCall: 1_000)
    let layer = SafetyLayer(signals: [], registry: ProtectedRegistry(userExcluded: [], systemProtected: []))
    let reclaimer = Reclaimer(safety: layer, deleter: deleter)

    let outcomes = await reclaimer.reclaim([pathItem("/Users/x/a"), pathItem("/Users/x/b")], dryRun: true)

    #expect(await deleter.callCount == 0)
    #expect(outcomes.count == 2)
    for outcome in outcomes {
        #expect(outcome.status == .dryRun(plannedBytes: 1_000))
    }
}

@Test func protectedItemIsNeverDeletedEvenWhenNotDryRun() async {
    let deleter = RecordingDeleter(bytesPerCall: 1_000)
    // Active signal downgrades the path to .protected.
    let layer = SafetyLayer(
        signals: [MockActivitySignal(name: "process", activePaths: ["/Users/x/inuse"])],
        registry: ProtectedRegistry(userExcluded: [], systemProtected: [])
    )
    let reclaimer = Reclaimer(safety: layer, deleter: deleter)

    let outcomes = await reclaimer.reclaim([pathItem("/Users/x/inuse")], dryRun: false)

    #expect(await deleter.callCount == 0)
    #expect(outcomes.first?.status == .skippedProtected)
}

@Test func nonProtectedItemIsDeletedWhenNotDryRun() async {
    let deleter = RecordingDeleter(bytesPerCall: 2_048)
    let layer = SafetyLayer(signals: [], registry: ProtectedRegistry(userExcluded: [], systemProtected: []))
    let reclaimer = Reclaimer(safety: layer, deleter: deleter)

    let outcomes = await reclaimer.reclaim([pathItem("/Users/x/cache")], dryRun: false)

    #expect(await deleter.callCount == 1)
    #expect(await deleter.calls.first == .init(path: "/Users/x/cache", toTrash: false))
    #expect(outcomes.first?.status == .deleted(bytes: 2_048))
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd DevSweep && swift test --filter ReclaimerTests`
Expected: FAIL — "cannot find 'Reclaimer' / 'ReclaimOutcome' in scope".

- [ ] **Step 3: Write minimal implementation**

Create `DevSweep/Sources/DevSweepCore/Reclaim/ReclaimOutcome.swift`:

```swift
/// What happened to one candidate during a reclaim pass.
public enum ReclaimStatus: Sendable, Equatable {
    /// Safety Layer downgraded it to `.protected`; not touched.
    case skippedProtected
    /// Dry-run: would have reclaimed this many bytes.
    case dryRun(plannedBytes: Int64)
    /// Actually deleted; bytes reclaimed as reported by the deleter.
    case deleted(bytes: Int64)
    /// Deletion attempted but failed.
    case failed(message: String)
}

public struct ReclaimOutcome: Sendable, Equatable {
    public let item: CleanupItem
    public let status: ReclaimStatus

    public init(item: CleanupItem, status: ReclaimStatus) {
        self.item = item
        self.status = status
    }
}
```

Create `DevSweep/Sources/DevSweepCore/Reclaim/Reclaimer.swift`:

```swift
/// Orchestrates reclaiming a set of candidates. Every item is re-evaluated through the
/// Safety Layer first. Dry-run produces a plan and never calls the deleter. Protected
/// items are skipped. CLI-based reclaim (docker prune etc.) lands in a later milestone.
public struct Reclaimer: Sendable {
    private let safety: SafetyLayer
    private let deleter: any FileSystemDeleter

    public init(safety: SafetyLayer, deleter: any FileSystemDeleter) {
        self.safety = safety
        self.deleter = deleter
    }

    public func reclaim(_ items: [CleanupItem], dryRun: Bool) async -> [ReclaimOutcome] {
        var outcomes: [ReclaimOutcome] = []
        for item in items {
            let resolved = await safety.evaluate(item).item

            if resolved.safety == .protected {
                outcomes.append(ReclaimOutcome(item: resolved, status: .skippedProtected))
                continue
            }
            if dryRun {
                outcomes.append(ReclaimOutcome(item: resolved, status: .dryRun(plannedBytes: resolved.sizeBytes)))
                continue
            }

            switch resolved.reclaimMethod {
            case .deletePath(let toTrash):
                guard let path = resolved.path else {
                    outcomes.append(ReclaimOutcome(item: resolved, status: .failed(message: "deletePath item has no path")))
                    continue
                }
                do {
                    let bytes = try await deleter.delete(path: path, toTrash: toTrash)
                    outcomes.append(ReclaimOutcome(item: resolved, status: .deleted(bytes: bytes)))
                } catch {
                    outcomes.append(ReclaimOutcome(item: resolved, status: .failed(message: String(describing: error))))
                }
            case .cliCommand:
                outcomes.append(ReclaimOutcome(item: resolved, status: .failed(message: "cliCommand reclaim is out of Milestone 1 scope")))
            }
        }
        return outcomes
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd DevSweep && swift test --filter ReclaimerTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add DevSweep/Sources/DevSweepCore/Reclaim DevSweep/Tests/DevSweepCoreTests/ReclaimerTests.swift
git commit -m "feat(devsweep): Reclaimer with dry-run + protected-skip invariants"
```

---

### Task 7: CommandRunner abstraction + mock + real impl

**Files:**
- Create: `DevSweep/Sources/DevSweepCore/Process/CommandRunner.swift`
- Create: `DevSweep/Sources/DevSweepCore/Process/ProcessCommandRunner.swift`
- Create: `DevSweep/Tests/DevSweepCoreTests/Support/MockCommandRunner.swift`
- Test: `DevSweep/Tests/DevSweepCoreTests/Support/MockCommandRunner.swift` self-check + a real-runner smoke test

- [ ] **Step 1: Write the failing test**

Create `DevSweep/Tests/DevSweepCoreTests/Support/MockCommandRunner.swift`:

```swift
import Foundation
import Testing
@testable import DevSweepCore

/// Test double: returns canned stdout keyed by executable, records invocations.
struct MockCommandRunner: CommandRunner {
    /// Map of executable path → stdout to return.
    let outputs: [String: String]

    func run(_ executable: String, _ args: [String]) async throws -> String {
        outputs[executable] ?? ""
    }
}

@Test func mockCommandRunnerReturnsCannedOutput() async throws {
    let runner = MockCommandRunner(outputs: ["/usr/bin/crontab": "0 3 * * * echo hi\n"])
    let out = try await runner.run("/usr/bin/crontab", ["-l"])
    #expect(out.contains("echo hi"))
}

@Test func processCommandRunnerCapturesEcho() async throws {
    let runner = ProcessCommandRunner()
    let out = try await runner.run("/bin/echo", ["devsweep-ok"])
    #expect(out.trimmingCharacters(in: .whitespacesAndNewlines) == "devsweep-ok")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd DevSweep && swift test --filter mockCommandRunnerReturnsCannedOutput`
Expected: FAIL — "cannot find type 'CommandRunner' in scope".

- [ ] **Step 3: Write minimal implementation**

Create `DevSweep/Sources/DevSweepCore/Process/CommandRunner.swift`:

```swift
/// Abstraction over running an external command and capturing stdout. Injected into
/// signals that wrap shell tools (lsof, crontab) so their parsing is unit-testable.
public protocol CommandRunner: Sendable {
    /// Run `executable` with `args`, returning stdout as a UTF-8 string.
    /// A non-zero exit returns whatever stdout was captured (does not throw on exit code).
    func run(_ executable: String, _ args: [String]) async throws -> String
}
```

Create `DevSweep/Sources/DevSweepCore/Process/ProcessCommandRunner.swift`:

```swift
import Foundation

/// Real CommandRunner backed by Foundation.Process. Thin on purpose — the testable
/// logic lives in the signals that parse the output, not here.
public struct ProcessCommandRunner: CommandRunner {
    public init() {}

    public func run(_ executable: String, _ args: [String]) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = args
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()  // discard stderr

        try process.run()
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd DevSweep && swift test --filter MockCommandRunner`
Then: `cd DevSweep && swift test --filter processCommandRunnerCapturesEcho`
Expected: PASS (both).

- [ ] **Step 5: Commit**

```bash
git add DevSweep/Sources/DevSweepCore/Process DevSweep/Tests/DevSweepCoreTests/Support/MockCommandRunner.swift
git commit -m "feat(devsweep): CommandRunner abstraction + Process-backed impl"
```

---

### Task 8: ProcessReferenceSignal (lsof)

**Files:**
- Create: `DevSweep/Sources/DevSweepCore/Safety/ProcessReferenceSignal.swift`
- Test: `DevSweep/Tests/DevSweepCoreTests/ProcessReferenceSignalTests.swift`

- [ ] **Step 1: Write the failing test**

Create `DevSweep/Tests/DevSweepCoreTests/ProcessReferenceSignalTests.swift`:

```swift
import Testing
@testable import DevSweepCore

@Test func processSignalActiveWhenLsofHasOutput() async {
    let runner = MockCommandRunner(outputs: [
        "/usr/sbin/lsof": "COMMAND  PID  USER ...\nopenclaw 3788 x cwd DIR /Users/x/.openclaw-pyiri\n"
    ])
    let signal = ProcessReferenceSignal(runner: runner)
    #expect(await signal.isActive(path: "/Users/x/.openclaw-pyiri") == true)
    #expect(signal.name == "process")
}

@Test func processSignalInactiveWhenLsofEmpty() async {
    let runner = MockCommandRunner(outputs: ["/usr/sbin/lsof": "   \n"])
    let signal = ProcessReferenceSignal(runner: runner)
    #expect(await signal.isActive(path: "/Users/x/.npm") == false)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd DevSweep && swift test --filter ProcessReferenceSignalTests`
Expected: FAIL — "cannot find 'ProcessReferenceSignal' in scope".

- [ ] **Step 3: Write minimal implementation**

Create `DevSweep/Sources/DevSweepCore/Safety/ProcessReferenceSignal.swift`:

```swift
/// Signal: is any process holding an open file under `path`? Uses `lsof +D <path>`.
/// Non-empty meaningful output ⇒ active. The command is mocked in tests.
public struct ProcessReferenceSignal: ActivitySignal {
    public let name = "process"
    private let runner: any CommandRunner

    public init(runner: any CommandRunner) {
        self.runner = runner
    }

    public func isActive(path: String) async -> Bool {
        let output = (try? await runner.run("/usr/sbin/lsof", ["+D", path])) ?? ""
        return !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd DevSweep && swift test --filter ProcessReferenceSignalTests`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add DevSweep/Sources/DevSweepCore/Safety/ProcessReferenceSignal.swift DevSweep/Tests/DevSweepCoreTests/ProcessReferenceSignalTests.swift
git commit -m "feat(devsweep): ProcessReferenceSignal (lsof-based active check)"
```

---

### Task 9: LaunchdReferenceSignal (LaunchAgents plist scan)

**Files:**
- Create: `DevSweep/Sources/DevSweepCore/Safety/LaunchdReferenceSignal.swift`
- Create: `DevSweep/Tests/DevSweepCoreTests/Support/TempDir.swift`
- Test: `DevSweep/Tests/DevSweepCoreTests/LaunchdReferenceSignalTests.swift`

- [ ] **Step 1: Write the temp-dir helper + failing test**

Create `DevSweep/Tests/DevSweepCoreTests/Support/TempDir.swift`:

```swift
import Foundation

/// Creates a unique temp directory for fixtures and removes it on `cleanup()`.
/// This is the ONLY place tests touch the real filesystem, and only under $TMPDIR.
struct TempDir {
    let url: URL

    init() {
        url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("devsweep-tests-" + UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    /// Write `contents` to a file at relative `name`, creating intermediate dirs.
    @discardableResult
    func writeFile(_ name: String, _ contents: String) -> String {
        let fileURL = url.appendingPathComponent(name)
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        try? contents.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL.path
    }

    /// Create an empty directory at relative `name` and return its absolute path.
    @discardableResult
    func makeDir(_ name: String) -> String {
        let dirURL = url.appendingPathComponent(name, isDirectory: true)
        try? FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
        return dirURL.path
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: url)
    }
}
```

Create `DevSweep/Tests/DevSweepCoreTests/LaunchdReferenceSignalTests.swift`:

```swift
import Testing
@testable import DevSweepCore

@Test func launchdSignalActiveWhenPlistReferencesPath() async {
    let temp = TempDir()
    defer { temp.cleanup() }
    let agentsDir = temp.makeDir("LaunchAgents")
    temp.writeFile("LaunchAgents/com.openclaw.pyiri.plist",
                   "<plist><dict><key>OPENCLAW_HOME</key><string>/Users/x/.openclaw-pyiri</string></dict></plist>")

    let signal = LaunchdReferenceSignal(launchAgentsDir: agentsDir)
    #expect(await signal.isActive(path: "/Users/x/.openclaw-pyiri") == true)
    #expect(await signal.isActive(path: "/Users/x/.npm") == false)
    #expect(signal.name == "launchd")
}

@Test func launchdSignalInactiveWhenAgentsDirMissing() async {
    let signal = LaunchdReferenceSignal(launchAgentsDir: "/nonexistent/LaunchAgents")
    #expect(await signal.isActive(path: "/Users/x/.openclaw-pyiri") == false)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd DevSweep && swift test --filter LaunchdReferenceSignalTests`
Expected: FAIL — "cannot find 'LaunchdReferenceSignal' in scope".

- [ ] **Step 3: Write minimal implementation**

Create `DevSweep/Sources/DevSweepCore/Safety/LaunchdReferenceSignal.swift`:

```swift
import Foundation

/// Signal: does any LaunchAgent plist reference `path`? A KeepAlive agent pointing into
/// the path means deleting the dir would break a managed service (the pyiri case).
public struct LaunchdReferenceSignal: ActivitySignal {
    public let name = "launchd"
    private let launchAgentsDir: String
    private let fileManager: FileManager

    public init(
        launchAgentsDir: String = (("~/Library/LaunchAgents") as NSString).expandingTildeInPath,
        fileManager: FileManager = .default
    ) {
        self.launchAgentsDir = launchAgentsDir
        self.fileManager = fileManager
    }

    public func isActive(path: String) async -> Bool {
        guard let entries = try? fileManager.contentsOfDirectory(atPath: launchAgentsDir) else {
            return false
        }
        for entry in entries where entry.hasSuffix(".plist") {
            let full = (launchAgentsDir as NSString).appendingPathComponent(entry)
            if let contents = try? String(contentsOfFile: full, encoding: .utf8),
               contents.contains(path) {
                return true
            }
        }
        return false
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd DevSweep && swift test --filter LaunchdReferenceSignalTests`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add DevSweep/Sources/DevSweepCore/Safety/LaunchdReferenceSignal.swift DevSweep/Tests/DevSweepCoreTests/Support/TempDir.swift DevSweep/Tests/DevSweepCoreTests/LaunchdReferenceSignalTests.swift
git commit -m "feat(devsweep): LaunchdReferenceSignal + TempDir fixture helper"
```

---

### Task 10: CrontabReferenceSignal

**Files:**
- Create: `DevSweep/Sources/DevSweepCore/Safety/CrontabReferenceSignal.swift`
- Test: `DevSweep/Tests/DevSweepCoreTests/CrontabReferenceSignalTests.swift`

- [ ] **Step 1: Write the failing test**

Create `DevSweep/Tests/DevSweepCoreTests/CrontabReferenceSignalTests.swift`:

```swift
import Testing
@testable import DevSweepCore

@Test func crontabSignalActiveWhenLineReferencesPath() async {
    let runner = MockCommandRunner(outputs: [
        "/usr/bin/crontab": "0 3 * * * find /Users/x/.openclaw-pyiri/logs -name '*.log' -mtime +7 -delete\n"
    ])
    let signal = CrontabReferenceSignal(runner: runner)
    #expect(await signal.isActive(path: "/Users/x/.openclaw-pyiri") == true)
    #expect(signal.name == "crontab")
}

@Test func crontabSignalInactiveWhenNoReference() async {
    let runner = MockCommandRunner(outputs: ["/usr/bin/crontab": "0 9 * * * /Users/x/other/run.sh\n"])
    let signal = CrontabReferenceSignal(runner: runner)
    #expect(await signal.isActive(path: "/Users/x/.openclaw-pyiri") == false)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd DevSweep && swift test --filter CrontabReferenceSignalTests`
Expected: FAIL — "cannot find 'CrontabReferenceSignal' in scope".

- [ ] **Step 3: Write minimal implementation**

Create `DevSweep/Sources/DevSweepCore/Safety/CrontabReferenceSignal.swift`:

```swift
/// Signal: does the user's crontab reference `path`? A scheduled job touching the path
/// means it is in active use. Output of `crontab -l` is mocked in tests.
public struct CrontabReferenceSignal: ActivitySignal {
    public let name = "crontab"
    private let runner: any CommandRunner

    public init(runner: any CommandRunner) {
        self.runner = runner
    }

    public func isActive(path: String) async -> Bool {
        let output = (try? await runner.run("/usr/bin/crontab", ["-l"])) ?? ""
        return output.contains(path)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd DevSweep && swift test --filter CrontabReferenceSignalTests`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add DevSweep/Sources/DevSweepCore/Safety/CrontabReferenceSignal.swift DevSweep/Tests/DevSweepCoreTests/CrontabReferenceSignalTests.swift
git commit -m "feat(devsweep): CrontabReferenceSignal"
```

---

### Task 11: RecentUseSignal (mtime threshold)

**Files:**
- Create: `DevSweep/Sources/DevSweepCore/Safety/RecentUseSignal.swift`
- Test: `DevSweep/Tests/DevSweepCoreTests/RecentUseSignalTests.swift`

- [ ] **Step 1: Write the failing test**

Create `DevSweep/Tests/DevSweepCoreTests/RecentUseSignalTests.swift`:

```swift
import Foundation
import Testing
@testable import DevSweepCore

@Test func recentUseActiveWhenModifiedWithinThreshold() async {
    let temp = TempDir()
    defer { temp.cleanup() }
    let file = temp.writeFile("fresh.txt", "x")
    // mtime = now; fixed clock = now ⇒ within 30 days.
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    try? FileManager.default.setAttributes([.modificationDate: now], ofItemAtPath: file)

    let signal = RecentUseSignal(thresholdDays: 30, now: { now })
    #expect(await signal.isActive(path: file) == true)
    #expect(signal.name == "recent-use")
}

@Test func recentUseInactiveWhenOlderThanThreshold() async {
    let temp = TempDir()
    defer { temp.cleanup() }
    let file = temp.writeFile("stale.txt", "x")
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let old = now.addingTimeInterval(-40 * 86_400)  // 40 days ago
    try? FileManager.default.setAttributes([.modificationDate: old], ofItemAtPath: file)

    let signal = RecentUseSignal(thresholdDays: 30, now: { now })
    #expect(await signal.isActive(path: file) == false)
}

@Test func recentUseInactiveForMissingPath() async {
    let signal = RecentUseSignal(thresholdDays: 30, now: { Date() })
    #expect(await signal.isActive(path: "/nonexistent/thing") == false)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd DevSweep && swift test --filter RecentUseSignalTests`
Expected: FAIL — "cannot find 'RecentUseSignal' in scope".

- [ ] **Step 3: Write minimal implementation**

Create `DevSweep/Sources/DevSweepCore/Safety/RecentUseSignal.swift`:

```swift
import Foundation

/// Signal: was `path` modified within `thresholdDays`? Recent modification means the
/// resource is likely still in use. The clock is injected for deterministic tests.
public struct RecentUseSignal: ActivitySignal {
    public let name = "recent-use"
    private let thresholdDays: Int
    private let now: @Sendable () -> Date
    private let fileManager: FileManager

    public init(
        thresholdDays: Int = 30,
        now: @escaping @Sendable () -> Date = Date.init,
        fileManager: FileManager = .default
    ) {
        self.thresholdDays = thresholdDays
        self.now = now
        self.fileManager = fileManager
    }

    public func isActive(path: String) async -> Bool {
        guard let attrs = try? fileManager.attributesOfItem(atPath: path),
              let mtime = attrs[.modificationDate] as? Date else {
            return false
        }
        let cutoff = now().addingTimeInterval(-Double(thresholdDays) * 86_400)
        return mtime >= cutoff
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd DevSweep && swift test --filter RecentUseSignalTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add DevSweep/Sources/DevSweepCore/Safety/RecentUseSignal.swift DevSweep/Tests/DevSweepCoreTests/RecentUseSignalTests.swift
git commit -m "feat(devsweep): RecentUseSignal (mtime threshold)"
```

---

### Task 12: ParentProjectActivitySignal (recent source in parent)

**Files:**
- Create: `DevSweep/Sources/DevSweepCore/Safety/ParentProjectActivitySignal.swift`
- Test: `DevSweep/Tests/DevSweepCoreTests/ParentProjectActivitySignalTests.swift`

- [ ] **Step 1: Write the failing test**

Create `DevSweep/Tests/DevSweepCoreTests/ParentProjectActivitySignalTests.swift`:

```swift
import Foundation
import Testing
@testable import DevSweepCore

@Test func parentProjectActiveWhenSiblingSourceIsRecent() async {
    let temp = TempDir()
    defer { temp.cleanup() }
    // project/ contains node_modules/ (candidate) and a recently edited src file.
    let nodeModules = temp.makeDir("project/node_modules")
    let src = temp.writeFile("project/src/index.ts", "console.log(1)")
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    try? FileManager.default.setAttributes([.modificationDate: now], ofItemAtPath: src)

    let signal = ParentProjectActivitySignal(thresholdDays: 30, now: { now })
    #expect(await signal.isActive(path: nodeModules) == true)
    #expect(signal.name == "parent-project")
}

@Test func parentProjectInactiveWhenAllSourceIsStale() async {
    let temp = TempDir()
    defer { temp.cleanup() }
    let nodeModules = temp.makeDir("project/node_modules")
    let src = temp.writeFile("project/src/index.ts", "console.log(1)")
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let old = now.addingTimeInterval(-90 * 86_400)
    try? FileManager.default.setAttributes([.modificationDate: old], ofItemAtPath: src)
    // also age the src dir itself
    try? FileManager.default.setAttributes([.modificationDate: old],
                                           ofItemAtPath: (src as NSString).deletingLastPathComponent)

    let signal = ParentProjectActivitySignal(thresholdDays: 30, now: { now })
    #expect(await signal.isActive(path: nodeModules) == false)
}

@Test func parentProjectIgnoresExcludedDirs() async {
    let temp = TempDir()
    defer { temp.cleanup() }
    let nodeModules = temp.makeDir("project/node_modules")
    // The only "recent" file lives inside an excluded dir (.git) → must be ignored.
    let gitFile = temp.writeFile("project/.git/COMMIT_EDITMSG", "wip")
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    try? FileManager.default.setAttributes([.modificationDate: now], ofItemAtPath: gitFile)

    let signal = ParentProjectActivitySignal(thresholdDays: 30, now: { now })
    #expect(await signal.isActive(path: nodeModules) == false)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd DevSweep && swift test --filter ParentProjectActivitySignalTests`
Expected: FAIL — "cannot find 'ParentProjectActivitySignal' in scope".

- [ ] **Step 3: Write minimal implementation**

Create `DevSweep/Sources/DevSweepCore/Safety/ParentProjectActivitySignal.swift`:

```swift
import Foundation

/// Signal: for a candidate like `.../project/node_modules`, is the *parent project*
/// active? Walks the parent dir (skipping excluded subdirs like node_modules/.git/.venv)
/// and returns true on the first source file modified within `thresholdDays`.
public struct ParentProjectActivitySignal: ActivitySignal {
    public let name = "parent-project"
    private let thresholdDays: Int
    private let now: @Sendable () -> Date
    private let fileManager: FileManager
    private let excludedDirNames: Set<String>

    public init(
        thresholdDays: Int = 30,
        now: @escaping @Sendable () -> Date = Date.init,
        fileManager: FileManager = .default,
        excludedDirNames: Set<String> = ["node_modules", ".git", ".venv", "venv", ".build"]
    ) {
        self.thresholdDays = thresholdDays
        self.now = now
        self.fileManager = fileManager
        self.excludedDirNames = excludedDirNames
    }

    public func isActive(path: String) async -> Bool {
        let parent = (path as NSString).deletingLastPathComponent
        let cutoff = now().addingTimeInterval(-Double(thresholdDays) * 86_400)
        return hasRecentFile(in: parent, cutoff: cutoff)
    }

    private func hasRecentFile(in dir: String, cutoff: Date) -> Bool {
        guard let entries = try? fileManager.contentsOfDirectory(atPath: dir) else { return false }
        for entry in entries {
            let full = (dir as NSString).appendingPathComponent(entry)
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: full, isDirectory: &isDir) else { continue }

            if isDir.boolValue {
                if excludedDirNames.contains(entry) { continue }
                if hasRecentFile(in: full, cutoff: cutoff) { return true }
            } else {
                if let attrs = try? fileManager.attributesOfItem(atPath: full),
                   let mtime = attrs[.modificationDate] as? Date,
                   mtime >= cutoff {
                    return true
                }
            }
        }
        return false
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd DevSweep && swift test --filter ParentProjectActivitySignalTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add DevSweep/Sources/DevSweepCore/Safety/ParentProjectActivitySignal.swift DevSweep/Tests/DevSweepCoreTests/ParentProjectActivitySignalTests.swift
git commit -m "feat(devsweep): ParentProjectActivitySignal (recent source in parent project)"
```

---

### Task 13: DefaultSafetyLayer factory + full pyiri integration

**Files:**
- Create: `DevSweep/Sources/DevSweepCore/Safety/DefaultSafetyLayer.swift`
- Test: `DevSweep/Tests/DevSweepCoreTests/DefaultSafetyLayerPyiriTests.swift`

- [ ] **Step 1: Write the failing test**

Create `DevSweep/Tests/DevSweepCoreTests/DefaultSafetyLayerPyiriTests.swift`:

```swift
import Foundation
import Testing
@testable import DevSweepCore

/// Capstone integration: compose the REAL signals (with mocked external commands and a
/// fixture LaunchAgents dir) and reproduce the full pyiri scenario end-to-end. The 4.7GB
/// candidate must be downgraded to .protected by process + launchd + crontab together.
@Test func defaultSafetyLayerProtectsPyiriEndToEnd() async {
    let temp = TempDir()
    defer { temp.cleanup() }
    let pyiri = temp.makeDir(".openclaw-pyiri")

    let agentsDir = temp.makeDir("LaunchAgents")
    temp.writeFile("LaunchAgents/com.openclaw.pyiri.plist",
                   "<plist><dict><key>OPENCLAW_HOME</key><string>\(pyiri)</string></dict></plist>")

    let commandRunner = MockCommandRunner(outputs: [
        "/usr/sbin/lsof": "openclaw 3788 x cwd DIR \(pyiri)\n",
        "/usr/bin/crontab": "0 3 * * * find \(pyiri)/logs -name '*.log' -mtime +7 -delete\n"
    ])

    let layer = DefaultSafetyLayer.make(
        commandRunner: commandRunner,
        launchAgentsDir: agentsDir,
        registry: ProtectedRegistry(userExcluded: [], systemProtected: [])
    )

    let candidate = CleanupItem(
        id: pyiri, path: pyiri, sizeBytes: 4_700_000_000, lastUsed: nil,
        safety: .reviewNeeded, reclaimMethod: .deletePath(toTrash: false)
    )
    let eval = await layer.evaluate(candidate)

    #expect(eval.item.safety == .protected)
    #expect(eval.downgradedBy.contains("process"))
    #expect(eval.downgradedBy.contains("launchd"))
    #expect(eval.downgradedBy.contains("crontab"))
}

/// A genuinely dead directory (no process, no launchd, no crontab, stale mtime, no recent
/// parent source) is NOT downgraded — it stays reclaimable.
@Test func defaultSafetyLayerLeavesDeadCacheReclaimable() async {
    let temp = TempDir()
    defer { temp.cleanup() }
    let deadCache = temp.makeDir("project/node_modules")
    // age the whole project so recent-use + parent-project are inactive
    let old = Date(timeIntervalSince1970: 1_700_000_000).addingTimeInterval(-120 * 86_400)
    try? FileManager.default.setAttributes([.modificationDate: old], ofItemAtPath: deadCache)

    let agentsDir = temp.makeDir("LaunchAgents")  // empty
    let commandRunner = MockCommandRunner(outputs: [
        "/usr/sbin/lsof": "",
        "/usr/bin/crontab": ""
    ])

    let layer = DefaultSafetyLayer.make(
        commandRunner: commandRunner,
        launchAgentsDir: agentsDir,
        registry: ProtectedRegistry(userExcluded: [], systemProtected: []),
        now: { Date(timeIntervalSince1970: 1_700_000_000) }
    )

    let candidate = CleanupItem(
        id: deadCache, path: deadCache, sizeBytes: 800_000_000, lastUsed: nil,
        safety: .reviewNeeded, reclaimMethod: .deletePath(toTrash: false)
    )
    let eval = await layer.evaluate(candidate)

    #expect(eval.item.safety == .reviewNeeded)
    #expect(eval.downgradedBy.isEmpty)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd DevSweep && swift test --filter DefaultSafetyLayerPyiriTests`
Expected: FAIL — "cannot find 'DefaultSafetyLayer' in scope".

- [ ] **Step 3: Write minimal implementation**

Create `DevSweep/Sources/DevSweepCore/Safety/DefaultSafetyLayer.swift`:

```swift
import Foundation

/// Factory that composes the production set of activity signals into a SafetyLayer.
/// External dependencies (command runner, LaunchAgents dir, clock) are injectable so
/// the same composition is exercised under test.
public enum DefaultSafetyLayer {
    public static func make(
        commandRunner: any CommandRunner = ProcessCommandRunner(),
        launchAgentsDir: String = (("~/Library/LaunchAgents") as NSString).expandingTildeInPath,
        registry: ProtectedRegistry = ProtectedRegistry(),
        thresholdDays: Int = 30,
        now: @escaping @Sendable () -> Date = Date.init
    ) -> SafetyLayer {
        let signals: [any ActivitySignal] = [
            ProcessReferenceSignal(runner: commandRunner),
            LaunchdReferenceSignal(launchAgentsDir: launchAgentsDir),
            CrontabReferenceSignal(runner: commandRunner),
            RecentUseSignal(thresholdDays: thresholdDays, now: now),
            ParentProjectActivitySignal(thresholdDays: thresholdDays, now: now)
        ]
        return SafetyLayer(signals: signals, registry: registry)
    }
}
```

- [ ] **Step 4: Run the full test suite to verify everything passes**

Run: `cd DevSweep && swift test`
Expected: PASS — all tests across every file green, including both `DefaultSafetyLayerPyiriTests` cases.

- [ ] **Step 5: Commit**

```bash
git add DevSweep/Sources/DevSweepCore/Safety/DefaultSafetyLayer.swift DevSweep/Tests/DevSweepCoreTests/DefaultSafetyLayerPyiriTests.swift
git commit -m "feat(devsweep): DefaultSafetyLayer factory + end-to-end pyiri integration test"
```

---

## Milestone 1 Done — Definition of Done

- `cd DevSweep && swift test` is fully green.
- The pyiri scenario is protected by both the unit test (Task 4) and the end-to-end integration test (Task 13). These are the safety contract; they must never be deleted or weakened.
- No test ever deletes a real file outside `$TMPDIR` (all destructive work goes through `FileSystemDeleter`, mocked in tests).
- `scan`/dry-run provably never call the deleter (Task 6).

## Remaining Milestones (roadmap — separate specs/plans)

These are out of scope for this plan and each gets its own brainstorming → spec → plan cycle:

- **M2 — Detector modules:** `CleanupModule` protocol + Docker (CLI), package-cache, node_modules/.venv detectors producing `CleanupItem`s. CLI-based reclaim path in `Reclaimer`.
- **M3 — Persistence & trends:** `Store` (SQLite) for history, trend deltas, and the audit log of every deletion.
- **M4 — App shell & menu bar:** SwiftUI menu-bar app, `SMAppService` login item, `Watcher` (NSBackgroundActivityScheduler + disk-pressure), `Notifier` (UNUserNotificationCenter + actions), review/approve UI.
- **M5 — Reclaimable indicator & skins:** `SkinRenderer` (NSStatusItem), `reclaimableBytes → visual variable` mapping, free skins (`df -h`, `Void`), `SkinModule` abstraction, golden-image snapshot tests.
- **M6 — Monetization:** `StoreKitManager` (skin IAP, StoreKit Testing), live preview, `DonationLinks` (BMC + GitHub Sponsors), Apple-guideline separation (skins=IAP, donations=reward-free external).

## Self-Review Notes

- **Spec coverage (M1 portion):** Safety Layer §3 gates ①②③ → Tasks 2,3,4; activity-check signals (process/launchd/crontab/recent/parent) → Tasks 8–12; dry-run + deleter abstraction (§3 gate ④ partial + §7 ①) → Tasks 5,6; pyiri regression (§3, §7 ①) → Tasks 4 & 13. Gate ④'s Trash/permanent real implementation (`TrashDeleter`) is defined in the file structure but its concrete impl + test is deferred to M2 alongside real detectors, since M1's deleter contract is fully exercised by the recording double — noting this explicitly so it is not mistaken for a gap.
- **Placeholder scan:** none — every code step contains full source.
- **Type consistency:** `CleanupItem`, `SafetyClass`, `ReclaimMethod`, `SafetyEvaluation`, `ActivitySignal.isActive(path:)`, `SafetyLayer.evaluate(_:)`, `FileSystemDeleter.delete(path:toTrash:)`, `CommandRunner.run(_:_:)`, `Reclaimer.reclaim(_:dryRun:)`, `ReclaimStatus` cases are used identically across all tasks.
