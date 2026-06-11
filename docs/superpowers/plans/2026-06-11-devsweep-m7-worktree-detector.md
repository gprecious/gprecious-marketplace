# DevSweep M7 — Git Worktree Detector Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a 4th `CleanupModule` (`WorktreeModule`) that reclaims merged/clean git worktrees as a unit via `git worktree remove`, with a data-loss-0 safety gate.

**Architecture:** Pure cores (porcelain parser + classifier + nested-suppressor) tested in isolation; a git-IO inspector and the module orchestrator built on `CommandRunner`/`DirectorySizer`/`ActivitySignal`; registered in `DefaultDetectorRegistry`. Mirrors `DockerModule`'s CLI-reclaim pattern. Spec: `docs/superpowers/specs/2026-06-11-devsweep-m7-worktree-detector-design.md`.

**Tech Stack:** Swift 6, macOS 14, SPM, Swift Testing (`@Test`/`#expect`). New source files auto-discovered by SPM (no `Package.swift` edit). Test doubles: `ScriptedCommandRunner` (FIFO by full command), temp dirs for sizing.

**Conventions (from the existing codebase):**
- Module IO source lives in `Sources/DevSweepCore/Detect/`; pure models in `Sources/DevSweepCore/Models/`.
- `CommandRunner.runResult(exe, args) -> CommandResult{stdout, exitCode}`; non-zero exit does NOT throw.
- Module command shape: `executable = "/usr/bin/env"`, `argPrefix = ["git"]` → scripted command key is `"/usr/bin/env git -C <repo> ..."`.
- `ReclaimStatus`: `.dryRun(plannedBytes:)` / `.deleted(bytes:)` / `.failed(message:)` / `.skippedProtected`.
- Run a single test: `swift test --filter <TestFuncName>`; full suite: `swift test`.

---

### Task 1: Porcelain parser (`WorktreeEntry` + `WorktreeListParser`)

**Files:**
- Create: `Sources/DevSweepCore/Models/WorktreeEntry.swift`
- Create: `Tests/DevSweepCoreTests/WorktreeListParserTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// Tests/DevSweepCoreTests/WorktreeListParserTests.swift
import Foundation
import Testing
@testable import DevSweepCore

private let porcelain = """
worktree /repo
HEAD aaaa1111
branch refs/heads/main

worktree /repo/.worktrees/feat
HEAD bbbb2222
branch refs/heads/feat/x

worktree /repo/.worktrees/locked-one
HEAD cccc3333
branch refs/heads/locked
locked working on it

worktree /repo/.worktrees/gonedir
HEAD dddd4444
detached
prunable gitdir file points to non-existent location

"""

@Test func parsesMainAndLinkedWorktrees() {
    let entries = WorktreeListParser.parse(porcelain)
    #expect(entries.count == 4)
    #expect(entries[0].isMain == true)
    #expect(entries[1].isMain == false)
    #expect(entries[0].path == "/repo")
    #expect(entries[1].path == "/repo/.worktrees/feat")
    #expect(entries[1].branch == "feat/x")
    #expect(entries[0].head == "aaaa1111")
}

@Test func parsesLockedPrunableDetachedFlags() {
    let entries = WorktreeListParser.parse(porcelain)
    #expect(entries[2].isLocked == true)
    #expect(entries[3].isPrunable == true)
    #expect(entries[3].branch == nil)        // detached
}

@Test func parseToleratesTrailingBlankAndEmptyInput() {
    #expect(WorktreeListParser.parse("").isEmpty)
    #expect(WorktreeListParser.parse("\n\n").isEmpty)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter parsesMainAndLinkedWorktrees`
Expected: FAIL — `cannot find 'WorktreeListParser' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
// Sources/DevSweepCore/Models/WorktreeEntry.swift
import Foundation

/// One entry from `git worktree list --porcelain`.
public struct WorktreeEntry: Sendable, Equatable {
    public let path: String
    public let head: String
    public let branch: String?   // short name; nil when detached
    public let isMain: Bool       // first entry in porcelain order
    public let isLocked: Bool
    public let isPrunable: Bool
    public let isBare: Bool

    public init(path: String, head: String, branch: String?, isMain: Bool,
                isLocked: Bool, isPrunable: Bool, isBare: Bool) {
        self.path = path; self.head = head; self.branch = branch; self.isMain = isMain
        self.isLocked = isLocked; self.isPrunable = isPrunable; self.isBare = isBare
    }
}

/// Parses `git worktree list --porcelain`. Blocks are separated by a blank line; the first
/// block is always the main working tree.
public enum WorktreeListParser {
    public static func parse(_ porcelain: String) -> [WorktreeEntry] {
        var entries: [WorktreeEntry] = []
        for block in porcelain.components(separatedBy: "\n\n") {
            let lines = block.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
            guard let wtLine = lines.first(where: { $0.hasPrefix("worktree ") }) else { continue }
            let path = String(wtLine.dropFirst("worktree ".count))
            var head = ""
            var branch: String? = nil
            var isLocked = false, isPrunable = false, isBare = false
            for line in lines {
                if line.hasPrefix("HEAD ") {
                    head = String(line.dropFirst("HEAD ".count))
                } else if line.hasPrefix("branch ") {
                    let ref = String(line.dropFirst("branch ".count))
                    branch = ref.hasPrefix("refs/heads/") ? String(ref.dropFirst("refs/heads/".count)) : ref
                } else if line == "detached" {
                    branch = nil
                } else if line == "bare" {
                    isBare = true
                } else if line == "locked" || line.hasPrefix("locked ") {
                    isLocked = true
                } else if line == "prunable" || line.hasPrefix("prunable ") {
                    isPrunable = true
                }
            }
            entries.append(WorktreeEntry(path: path, head: head, branch: branch,
                                         isMain: entries.isEmpty, isLocked: isLocked,
                                         isPrunable: isPrunable, isBare: isBare))
        }
        return entries
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter WorktreeListParser`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/DevSweepCore/Models/WorktreeEntry.swift Tests/DevSweepCoreTests/WorktreeListParserTests.swift
git commit -m "feat(devsweep): M7 worktree porcelain parser"
```

---

### Task 2: Pure classifier (`WorktreeFacts` + `WorktreeClassifier`)

**Files:**
- Create: `Sources/DevSweepCore/Models/WorktreeClassification.swift`
- Create: `Tests/DevSweepCoreTests/WorktreeClassifierTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// Tests/DevSweepCoreTests/WorktreeClassifierTests.swift
import Testing
@testable import DevSweepCore

private func facts(main: Bool = false, locked: Bool = false, dirty: Bool = false,
                   localOnly: Bool = false, active: Bool = false,
                   label: WorktreeMergeLabel = .pushedUnmerged) -> WorktreeFacts {
    WorktreeFacts(isMain: main, isLocked: locked, isDirty: dirty,
                  hasLocalOnlyCommits: localOnly, isActive: active, mergeLabel: label)
}

@Test func mainWorktreeIsProtected() {
    #expect(WorktreeClassifier.classify(facts(main: true)).0 == .protected)
}

@Test func cleanPushedUnmergedIsCandidate() {
    let (safety, reason) = WorktreeClassifier.classify(facts(label: .pushedUnmerged))
    #expect(safety == .reviewNeeded)
    #expect(reason == .candidate(label: .pushedUnmerged))
}

@Test func cleanMergedIsCandidate() {
    let (safety, reason) = WorktreeClassifier.classify(facts(label: .merged))
    #expect(safety == .reviewNeeded)
    #expect(reason == .candidate(label: .merged))
}

@Test func localOnlyCommitsAreProtected() {     // data-loss-0 core
    #expect(WorktreeClassifier.classify(facts(localOnly: true)).0 == .protected)
}

@Test func dirtyLockedActiveAreProtected() {
    #expect(WorktreeClassifier.classify(facts(dirty: true)).0 == .protected)
    #expect(WorktreeClassifier.classify(facts(locked: true)).0 == .protected)
    #expect(WorktreeClassifier.classify(facts(active: true)).0 == .protected)
}

@Test func protectionPrecedesCandidate() {
    // even if "merged", any protect condition wins
    #expect(WorktreeClassifier.classify(facts(dirty: true, label: .merged)).0 == .protected)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter mainWorktreeIsProtected`
Expected: FAIL — `cannot find 'WorktreeClassifier' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
// Sources/DevSweepCore/Models/WorktreeClassification.swift

/// Display-only "how merged" label for a candidate worktree. Never a safety gate.
public enum WorktreeMergeLabel: Sendable, Equatable {
    case merged          // ancestor-merged OR content-empty OR upstream gone
    case pushedUnmerged  // not merged to default, but all commits are on a remote
}

/// Why a worktree got its safety class (drives UI copy + tests).
public enum WorktreeSafetyReason: Sendable, Equatable {
    case mainWorktree
    case locked
    case dirty
    case localOnlyCommits
    case active
    case candidate(label: WorktreeMergeLabel)
}

/// Git-derived facts the classifier reasons over. All booleans are computed by the inspector.
public struct WorktreeFacts: Sendable, Equatable {
    public let isMain: Bool
    public let isLocked: Bool
    public let isDirty: Bool
    public let hasLocalOnlyCommits: Bool
    public let isActive: Bool
    public let mergeLabel: WorktreeMergeLabel

    public init(isMain: Bool, isLocked: Bool, isDirty: Bool,
                hasLocalOnlyCommits: Bool, isActive: Bool, mergeLabel: WorktreeMergeLabel) {
        self.isMain = isMain; self.isLocked = isLocked; self.isDirty = isDirty
        self.hasLocalOnlyCommits = hasLocalOnlyCommits; self.isActive = isActive; self.mergeLabel = mergeLabel
    }
}

/// Data-loss-0 gate. ANY protect condition wins; only a fully-safe worktree is a candidate.
public enum WorktreeClassifier {
    public static func classify(_ f: WorktreeFacts) -> (SafetyClass, WorktreeSafetyReason) {
        if f.isMain { return (.protected, .mainWorktree) }
        if f.isLocked { return (.protected, .locked) }
        if f.isDirty { return (.protected, .dirty) }
        if f.hasLocalOnlyCommits { return (.protected, .localOnlyCommits) }
        if f.isActive { return (.protected, .active) }
        return (.reviewNeeded, .candidate(label: f.mergeLabel))
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter WorktreeClassifier`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/DevSweepCore/Models/WorktreeClassification.swift Tests/DevSweepCoreTests/WorktreeClassifierTests.swift
git commit -m "feat(devsweep): M7 worktree data-loss-0 classifier"
```

---

### Task 3: Git IO (`GitWorktreeInspector`)

**Files:**
- Create: `Sources/DevSweepCore/Detect/GitWorktreeInspector.swift`
- Create: `Tests/DevSweepCoreTests/GitWorktreeInspectorTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// Tests/DevSweepCoreTests/GitWorktreeInspectorTests.swift
import Testing
@testable import DevSweepCore

@Test func inspectorListsWorktrees() async {
    let runner = ScriptedCommandRunner([
        "/usr/bin/env git -C /repo worktree list --porcelain":
            [.init(stdout: "worktree /repo\nHEAD a1\nbranch refs/heads/main\n\nworktree /repo/.worktrees/f\nHEAD b2\nbranch refs/heads/f\n")]
    ])
    let entries = await GitWorktreeInspector(runner: runner).worktrees(inRepo: "/repo")
    #expect(entries.count == 2)
    #expect(entries[1].branch == "f")
}

@Test func inspectorDefaultBranchStripsOriginPrefix() async {
    let runner = ScriptedCommandRunner([
        "/usr/bin/env git -C /repo symbolic-ref --short refs/remotes/origin/HEAD": [.init(stdout: "origin/main\n")]
    ])
    #expect(await GitWorktreeInspector(runner: runner).defaultBranch(repo: "/repo") == "main")
}

@Test func inspectorDirtyTrueWhenStatusNonEmpty() async {
    let dirty = ScriptedCommandRunner(["/usr/bin/env git -C /wt status --porcelain": [.init(stdout: " M file.txt\n")]])
    let clean = ScriptedCommandRunner(["/usr/bin/env git -C /wt status --porcelain": [.init(stdout: "")]])
    #expect(await GitWorktreeInspector(runner: dirty).isDirty(worktree: "/wt") == true)
    #expect(await GitWorktreeInspector(runner: clean).isDirty(worktree: "/wt") == false)
}

@Test func inspectorLocalOnlyCommitsFromRevListCount() async {
    let has = ScriptedCommandRunner(["/usr/bin/env git -C /repo rev-list --count b2 --not --remotes main": [.init(stdout: "3\n")]])
    let none = ScriptedCommandRunner(["/usr/bin/env git -C /repo rev-list --count b2 --not --remotes main": [.init(stdout: "0\n")]])
    #expect(await GitWorktreeInspector(runner: has).hasLocalOnlyCommits(repo: "/repo", head: "b2", defaultBranch: "main") == true)
    #expect(await GitWorktreeInspector(runner: none).hasLocalOnlyCommits(repo: "/repo", head: "b2", defaultBranch: "main") == false)
}

@Test func inspectorLocalOnlyFailsSafeOnError() async {  // git error ⇒ treat as has-local-only ⇒ protected
    let err = ScriptedCommandRunner(["/usr/bin/env git -C /repo rev-list --count b2 --not --remotes main": [.init(exitCode: 128)]])
    #expect(await GitWorktreeInspector(runner: err).hasLocalOnlyCommits(repo: "/repo", head: "b2", defaultBranch: "main") == true)
}

@Test func inspectorMergeLabelAncestorIsMerged() async {
    let runner = ScriptedCommandRunner([
        "/usr/bin/env git -C /repo merge-base --is-ancestor b2 main": [.init(exitCode: 0)]
    ])
    #expect(await GitWorktreeInspector(runner: runner).mergeLabel(repo: "/repo", branch: "f", head: "b2", defaultBranch: "main") == .merged)
}

@Test func inspectorMergeLabelUpstreamGoneIsMerged() async {
    let runner = ScriptedCommandRunner([
        "/usr/bin/env git -C /repo merge-base --is-ancestor b2 main": [.init(exitCode: 1)],
        "/usr/bin/env git -C /repo for-each-ref --format=%(upstream:track) refs/heads/f": [.init(stdout: "[gone]\n")]
    ])
    #expect(await GitWorktreeInspector(runner: runner).mergeLabel(repo: "/repo", branch: "f", head: "b2", defaultBranch: "main") == .merged)
}

@Test func inspectorMergeLabelDefaultsPushedUnmerged() async {
    let runner = ScriptedCommandRunner([
        "/usr/bin/env git -C /repo merge-base --is-ancestor b2 main": [.init(exitCode: 1)],
        "/usr/bin/env git -C /repo for-each-ref --format=%(upstream:track) refs/heads/f": [.init(stdout: "\n")],
        "/usr/bin/env git -C /repo diff --quiet main...b2": [.init(exitCode: 1)]
    ])
    #expect(await GitWorktreeInspector(runner: runner).mergeLabel(repo: "/repo", branch: "f", head: "b2", defaultBranch: "main") == .pushedUnmerged)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter inspectorListsWorktrees`
Expected: FAIL — `cannot find 'GitWorktreeInspector' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
// Sources/DevSweepCore/Detect/GitWorktreeInspector.swift
import Foundation

/// Thin git wrapper: one method per fact the classifier needs. All commands go through
/// `CommandRunner` (mockable). Read-only — never mutates the repo.
public struct GitWorktreeInspector: Sendable {
    private let runner: any CommandRunner
    private let executable: String
    private let argPrefix: [String]

    public init(runner: any CommandRunner, executable: String = "/usr/bin/env", argPrefix: [String] = ["git"]) {
        self.runner = runner; self.executable = executable; self.argPrefix = argPrefix
    }

    private func run(_ args: [String]) async -> CommandResult? {
        try? await runner.runResult(executable, argPrefix + args)
    }

    public func worktrees(inRepo repo: String) async -> [WorktreeEntry] {
        guard let r = await run(["-C", repo, "worktree", "list", "--porcelain"]), r.exitCode == 0 else { return [] }
        return WorktreeListParser.parse(r.stdout)
    }

    public func defaultBranch(repo: String) async -> String {
        if let r = await run(["-C", repo, "symbolic-ref", "--short", "refs/remotes/origin/HEAD"]), r.exitCode == 0 {
            let name = r.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            if let range = name.range(of: "origin/") { return String(name[range.upperBound...]) }
            if !name.isEmpty { return name }
        }
        let r = await run(["-C", repo, "rev-parse", "--abbrev-ref", "HEAD"])
        let head = r?.stdout.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return head.isEmpty ? "main" : head
    }

    public func isDirty(worktree path: String) async -> Bool {
        guard let r = await run(["-C", path, "status", "--porcelain"]) else { return true } // fail-safe ⇒ protected
        return !r.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// True if any commit reachable from `head` is on neither a remote nor `defaultBranch`.
    /// Fail-safe: git error ⇒ true (treat as local work present ⇒ protected).
    public func hasLocalOnlyCommits(repo: String, head: String, defaultBranch: String) async -> Bool {
        guard let r = await run(["-C", repo, "rev-list", "--count", head, "--not", "--remotes", defaultBranch]),
              r.exitCode == 0 else { return true }
        return (Int(r.stdout.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 1) > 0
    }

    public func mergeLabel(repo: String, branch: String?, head: String, defaultBranch: String) async -> WorktreeMergeLabel {
        if let r = await run(["-C", repo, "merge-base", "--is-ancestor", head, defaultBranch]), r.exitCode == 0 {
            return .merged
        }
        if let branch, let r = await run(["-C", repo, "for-each-ref", "--format=%(upstream:track)", "refs/heads/\(branch)"]),
           r.stdout.contains("gone") {
            return .merged
        }
        if let r = await run(["-C", repo, "diff", "--quiet", "\(defaultBranch)...\(head)"]), r.exitCode == 0 {
            return .merged
        }
        return .pushedUnmerged
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter GitWorktreeInspector`
Expected: PASS (8 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/DevSweepCore/Detect/GitWorktreeInspector.swift Tests/DevSweepCoreTests/GitWorktreeInspectorTests.swift
git commit -m "feat(devsweep): M7 git worktree inspector (read-only facts)"
```

---

### Task 4: `WorktreeModule.scan()`

**Files:**
- Create: `Sources/DevSweepCore/Detect/WorktreeModule.swift`
- Create: `Tests/DevSweepCoreTests/WorktreeModuleScanTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// Tests/DevSweepCoreTests/WorktreeModuleScanTests.swift
import Foundation
import Testing
@testable import DevSweepCore

/// Always-inactive signal so scan() tests isolate git-state from process activity.
private struct InactiveSignal: ActivitySignal {
    let name = "inactive-test"
    func isActive(path: String) async -> Bool { false }
}

private func makeRunner(repo: String) -> ScriptedCommandRunner {
    ScriptedCommandRunner([
        "/usr/bin/env git --version": [.init(stdout: "git version 2.x", exitCode: 0)],
        "/usr/bin/env git -C \(repo) worktree list --porcelain": [.init(stdout: """
        worktree \(repo)
        HEAD m0
        branch refs/heads/main

        worktree \(repo)/.worktrees/cand
        HEAD c1
        branch refs/heads/cand

        """)],
        "/usr/bin/env git -C \(repo) symbolic-ref --short refs/remotes/origin/HEAD": [.init(stdout: "origin/main\n")],
        "/usr/bin/env git -C \(repo)/.worktrees/cand status --porcelain": [.init(stdout: "")],            // clean
        "/usr/bin/env git -C \(repo) rev-list --count c1 --not --remotes main": [.init(stdout: "0\n")],    // all pushed
        "/usr/bin/env git -C \(repo) merge-base --is-ancestor c1 main": [.init(exitCode: 1)],
        "/usr/bin/env git -C \(repo) for-each-ref --format=%(upstream:track) refs/heads/cand": [.init(stdout: "\n")],
        "/usr/bin/env git -C \(repo) diff --quiet main...c1": [.init(exitCode: 1)]
    ])
}

@Test func scanEmitsCleanPushedWorktreeAsReviewCandidate() async throws {
    let repo = "/tmp/devsweep-m7-\(UInt64.random(in: 0..<999999))"
    let runner = makeRunner(repo: repo)
    let module = WorktreeModule(roots: [], runner: runner,
                                activitySignal: InactiveSignal(),
                                repoLocator: { _ in [repo] })
    let items = await module.scan()
    #expect(items.count == 1)
    #expect(items[0].path == "\(repo)/.worktrees/cand")
    #expect(items[0].safety == .reviewNeeded)
    if case let .cliCommand(exe, args) = items[0].reclaimMethod {
        #expect(exe == "/usr/bin/env")
        #expect(args == ["git", "-C", repo, "worktree", "remove", "\(repo)/.worktrees/cand"])
    } else { Issue.record("worktree item must be cliCommand") }
}

@Test func scanProtectsWorktreeWithLocalOnlyCommits() async {
    let repo = "/tmp/devsweep-m7-\(UInt64.random(in: 0..<999999))"
    let runner = makeRunner(repo: repo)
    await runner.override("/usr/bin/env git -C \(repo) rev-list --count c1 --not --remotes main", [.init(stdout: "2\n")])
    let module = WorktreeModule(roots: [], runner: runner, activitySignal: InactiveSignal(), repoLocator: { _ in [repo] })
    #expect(await module.scan().isEmpty)   // protected ⇒ not emitted
}

@Test func scanProtectsDirtyWorktree() async {
    let repo = "/tmp/devsweep-m7-\(UInt64.random(in: 0..<999999))"
    let runner = makeRunner(repo: repo)
    await runner.override("/usr/bin/env git -C \(repo)/.worktrees/cand status --porcelain", [.init(stdout: " M x\n")])
    let module = WorktreeModule(roots: [], runner: runner, activitySignal: InactiveSignal(), repoLocator: { _ in [repo] })
    #expect(await module.scan().isEmpty)
}

@Test func scanNeverEmitsMainWorktree() async {
    let repo = "/tmp/devsweep-m7-\(UInt64.random(in: 0..<999999))"
    let runner = makeRunner(repo: repo)
    let module = WorktreeModule(roots: [], runner: runner, activitySignal: InactiveSignal(), repoLocator: { _ in [repo] })
    let items = await module.scan()
    #expect(items.allSatisfy { $0.path != repo })
}

@Test func scanUnavailableWhenGitMissing() async {
    let runner = ScriptedCommandRunner(["/usr/bin/env git --version": [.init(exitCode: 127)]])
    let module = WorktreeModule(roots: [], runner: runner, activitySignal: InactiveSignal(), repoLocator: { _ in [] })
    #expect(await module.isAvailable() == false)
}
```

This test needs a small `override` helper on the FIFO runner. Add it to the test double:

```swift
// Append to Tests/DevSweepCoreTests/Support/ScriptedCommandRunner.swift (inside the actor)
func override(_ key: String, _ responses: [Response]) { queues[key] = responses }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter scanEmitsCleanPushedWorktreeAsReviewCandidate`
Expected: FAIL — `cannot find 'WorktreeModule' in scope` (and `override` missing until the helper is added).

- [ ] **Step 3: Write minimal implementation**

```swift
// Sources/DevSweepCore/Detect/WorktreeModule.swift
import Foundation

/// 4th CleanupModule: reclaims merged/clean git worktrees as a unit via `git worktree remove`.
/// CLI-reclaim (like DockerModule). Data-loss-0: only clean + unlocked + fully-pushed + inactive
/// worktrees are emitted (as `.reviewNeeded`); everything else is protected (not shown).
public struct WorktreeModule: CleanupModule, @unchecked Sendable {
    public let id = "git-worktrees"
    public let displayName = "Git Worktrees"

    private let roots: [String]
    private let runner: any CommandRunner
    private let inspector: GitWorktreeInspector
    private let sizer: DirectorySizer
    private let activitySignal: any ActivitySignal
    private let repoLocator: @Sendable ([String]) -> [String]
    private let executable: String
    private let argPrefix: [String]

    public init(roots: [String],
                runner: any CommandRunner,
                sizer: DirectorySizer = DirectorySizer(),
                activitySignal: (any ActivitySignal)? = nil,
                repoLocator: (@Sendable ([String]) -> [String])? = nil,
                executable: String = "/usr/bin/env",
                argPrefix: [String] = ["git"]) {
        self.roots = roots
        self.runner = runner
        self.inspector = GitWorktreeInspector(runner: runner, executable: executable, argPrefix: argPrefix)
        self.sizer = sizer
        self.activitySignal = activitySignal ?? ProcessReferenceSignal(runner: runner)
        self.repoLocator = repoLocator ?? Self.defaultRepoLocator
        self.executable = executable
        self.argPrefix = argPrefix
    }

    public func isAvailable() async -> Bool {
        guard let r = try? await runner.runResult(executable, argPrefix + ["--version"]) else { return false }
        return r.exitCode == 0
    }

    public func scan() async -> [CleanupItem] {
        var items: [CleanupItem] = []
        for repo in repoLocator(roots) {
            let entries = await inspector.worktrees(inRepo: repo)
            guard entries.count > 1 else { continue }   // main only ⇒ nothing to reclaim
            let def = await inspector.defaultBranch(repo: repo)
            var orphanCount = 0
            for entry in entries where !entry.isMain {
                if entry.isPrunable { orphanCount += 1; continue }
                let dirty = await inspector.isDirty(worktree: entry.path)
                let localOnly = await inspector.hasLocalOnlyCommits(repo: repo, head: entry.head, defaultBranch: def)
                let active = await activitySignal.isActive(path: entry.path)
                let label = await inspector.mergeLabel(repo: repo, branch: entry.branch, head: entry.head, defaultBranch: def)
                let facts = WorktreeFacts(isMain: false, isLocked: entry.isLocked, isDirty: dirty,
                                          hasLocalOnlyCommits: localOnly, isActive: active, mergeLabel: label)
                guard WorktreeClassifier.classify(facts).0 == .reviewNeeded else { continue }
                items.append(CleanupItem(
                    id: entry.path, path: entry.path,
                    sizeBytes: sizer.size(of: entry.path), lastUsed: nil,
                    safety: .reviewNeeded,
                    reclaimMethod: .cliCommand(executable: executable,
                                               arguments: argPrefix + ["-C", repo, "worktree", "remove", entry.path])))
            }
            if orphanCount > 0 {
                items.append(CleanupItem(
                    id: "git-worktrees:orphans:\(repo)", path: nil,
                    sizeBytes: 0, lastUsed: nil, safety: .reviewNeeded,
                    reclaimMethod: .cliCommand(executable: executable, arguments: argPrefix + ["-C", repo, "worktree", "prune"])))
            }
        }
        return items
    }

    public func reclaim(_ items: [CleanupItem], dryRun: Bool) async -> [ReclaimOutcome] {
        await reclaimImpl(items, dryRun: dryRun)   // defined in Task 5
    }

    /// Bounded filesystem walk for main repos (a `.git` directory). Does not descend into a
    /// found repo — git enumerates its nested `.worktrees/` for us. Never follows symlinks.
    static let defaultRepoLocator: @Sendable ([String]) -> [String] = { roots in
        let fm = FileManager.default
        var repos: [String] = []
        for root in roots {
            var stack: [(String, Int)] = [(root, 0)]
            while let (dir, depth) = stack.popLast() {
                guard depth <= 4, let entries = try? fm.contentsOfDirectory(atPath: dir) else { continue }
                let gitPath = (dir as NSString).appendingPathComponent(".git")
                var gitIsDir: ObjCBool = false
                if fm.fileExists(atPath: gitPath, isDirectory: &gitIsDir), gitIsDir.boolValue {
                    repos.append(dir); continue
                }
                for entry in entries where !entry.hasPrefix(".") {
                    let full = (dir as NSString).appendingPathComponent(entry)
                    guard let attrs = try? fm.attributesOfItem(atPath: full),
                          (attrs[.type] as? FileAttributeType) == .typeDirectory else { continue }
                    stack.append((full, depth + 1))
                }
            }
        }
        return repos
    }
}
```

Add a placeholder `reclaimImpl` so the file compiles before Task 5 (Task 5 replaces it):

```swift
// Temporary stub at the bottom of WorktreeModule.swift — replaced in Task 5.
extension WorktreeModule {
    func reclaimImpl(_ items: [CleanupItem], dryRun: Bool) async -> [ReclaimOutcome] { [] }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter WorktreeModuleScan`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/DevSweepCore/Detect/WorktreeModule.swift \
        Tests/DevSweepCoreTests/WorktreeModuleScanTests.swift \
        Tests/DevSweepCoreTests/Support/ScriptedCommandRunner.swift
git commit -m "feat(devsweep): M7 WorktreeModule scan (candidate emission + safety gate)"
```

---

### Task 5: `WorktreeModule.reclaim()`

**Files:**
- Modify: `Sources/DevSweepCore/Detect/WorktreeModule.swift` (replace the `reclaimImpl` stub)
- Create: `Tests/DevSweepCoreTests/WorktreeModuleReclaimTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// Tests/DevSweepCoreTests/WorktreeModuleReclaimTests.swift
import Foundation
import Testing
@testable import DevSweepCore

private func removeItem(repo: String, path: String, bytes: Int64 = 0) -> CleanupItem {
    CleanupItem(id: path, path: path, sizeBytes: bytes, lastUsed: nil, safety: .reviewNeeded,
                reclaimMethod: .cliCommand(executable: "/usr/bin/env",
                                           arguments: ["git", "-C", repo, "worktree", "remove", path]))
}

@Test func reclaimRefusesForce() async {
    let item = CleanupItem(id: "/wt", path: "/wt", sizeBytes: 0, lastUsed: nil, safety: .reviewNeeded,
                           reclaimMethod: .cliCommand(executable: "/usr/bin/env",
                                                      arguments: ["git", "-C", "/repo", "worktree", "remove", "--force", "/wt"]))
    let module = WorktreeModule(roots: [], runner: ScriptedCommandRunner([:]), repoLocator: { _ in [] })
    let out = await module.reclaim([item], dryRun: false)
    #expect(out[0].status == .failed(message: "refusing git worktree command with --force"))
}

@Test func reclaimDryRunHasNoSideEffects() async {
    let item = removeItem(repo: "/repo", path: "/repo/.worktrees/x", bytes: 123)
    let module = WorktreeModule(roots: [], runner: ScriptedCommandRunner([:]), repoLocator: { _ in [] })
    let out = await module.reclaim([item], dryRun: true)
    #expect(out[0].status == .dryRun(plannedBytes: 123))
}

@Test func reclaimDeletesAndReportsDuBytes() async throws {
    // Real temp dir for sizing; stub fileExists ⇒ false (gone) so we don't depend on git actually removing it.
    let tmp = NSTemporaryDirectory() + "devsweep-m7-rm-\(UInt64.random(in: 0..<999999))"
    try "0123456789".write(toFile: try makeFile(in: tmp), atomically: true, encoding: .utf8)
    let runner = ScriptedCommandRunner([
        "/usr/bin/env git -C /repo worktree remove \(tmp)": [.init(exitCode: 0)]
    ])
    let module = WorktreeModule(roots: [], runner: runner, repoLocator: { _ in [] },
                                fileExists: { _ in false })   // path gone after remove
    let out = await module.reclaim([removeItem(repo: "/repo", path: tmp)], dryRun: false)
    #expect(out[0].status == .deleted(bytes: 10))
    try? FileManager.default.removeItem(atPath: tmp)
}

@Test func reclaimFailsWhenPathStillPresentAfterRemove() async {
    // Defense: git returned 0 but path remains ⇒ failure, not a false "deleted".
    let runner = ScriptedCommandRunner(["/usr/bin/env git -C /repo worktree remove /wt": [.init(exitCode: 0)]])
    let module = WorktreeModule(roots: [], runner: runner, repoLocator: { _ in [] }, fileExists: { _ in true })
    let out = await module.reclaim([removeItem(repo: "/repo", path: "/wt")], dryRun: false)
    if case .failed = out[0].status {} else { Issue.record("expected .failed when path persists") }
}

@Test func reclaimFailsWhenGitExitsNonZero() async {
    let runner = ScriptedCommandRunner(["/usr/bin/env git -C /repo worktree remove /wt": [.init(exitCode: 1)]])
    let module = WorktreeModule(roots: [], runner: runner, repoLocator: { _ in [] }, fileExists: { _ in false })
    let out = await module.reclaim([removeItem(repo: "/repo", path: "/wt")], dryRun: false)
    if case .failed = out[0].status {} else { Issue.record("expected .failed on non-zero git exit") }
}

@Test func reclaimPruneReportsZeroBytes() async {
    let runner = ScriptedCommandRunner(["/usr/bin/env git -C /repo worktree prune": [.init(exitCode: 0)]])
    let item = CleanupItem(id: "git-worktrees:orphans:/repo", path: nil, sizeBytes: 0, lastUsed: nil,
                           safety: .reviewNeeded,
                           reclaimMethod: .cliCommand(executable: "/usr/bin/env",
                                                      arguments: ["git", "-C", "/repo", "worktree", "prune"]))
    let module = WorktreeModule(roots: [], runner: runner, repoLocator: { _ in [] }, fileExists: { _ in true })
    #expect(await module.reclaim([item], dryRun: false)[0].status == .deleted(bytes: 0))
}

// helper
private func makeFile(in dir: String) throws -> String {
    try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    return (dir as NSString).appendingPathComponent("f.txt")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter reclaimRefusesForce`
Expected: FAIL — `WorktreeModule` has no `fileExists:` initializer parameter; `reclaimImpl` stub returns `[]`.

- [ ] **Step 3: Write minimal implementation**

Add a `fileExists` dependency to the initializer (so the path-gone check is testable). In `WorktreeModule`:

```swift
// add stored property
private let fileExists: @Sendable (String) -> Bool

// add parameter to init (with default) and store it:
//   fileExists: (@Sendable (String) -> Bool)? = nil,
//   self.fileExists = fileExists ?? { FileManager.default.fileExists(atPath: $0) }
```

Replace the temporary `reclaimImpl` stub with:

```swift
extension WorktreeModule {
    func reclaimImpl(_ items: [CleanupItem], dryRun: Bool) async -> [ReclaimOutcome] {
        var outcomes: [ReclaimOutcome] = []
        for item in items {
            guard case let .cliCommand(exe, args) = item.reclaimMethod else {
                outcomes.append(ReclaimOutcome(item: item, status: .failed(message: "WorktreeModule expects cliCommand items"))); continue
            }
            if args.contains("--force") {
                outcomes.append(ReclaimOutcome(item: item, status: .failed(message: "refusing git worktree command with --force"))); continue
            }
            if dryRun {
                outcomes.append(ReclaimOutcome(item: item, status: .dryRun(plannedBytes: item.sizeBytes))); continue
            }
            let isPrune = args.contains("prune")
            let before: Int64 = item.path.map { sizer.size(of: $0) } ?? 0
            guard let result = try? await runner.runResult(exe, args), result.exitCode == 0 else {
                outcomes.append(ReclaimOutcome(item: item, status: .failed(message: "git worktree command failed"))); continue
            }
            if isPrune {
                outcomes.append(ReclaimOutcome(item: item, status: .deleted(bytes: 0)))
            } else if let path = item.path, fileExists(path) {
                outcomes.append(ReclaimOutcome(item: item, status: .failed(message: "worktree path still present after remove")))
            } else {
                outcomes.append(ReclaimOutcome(item: item, status: .deleted(bytes: before)))
            }
        }
        return outcomes
    }
}
```

Update the `WorktreeModuleScanTests` constructions if needed — they omit `fileExists`, which is fine (it has a default).

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter WorktreeModuleReclaim`
Expected: PASS (6 tests). Then `swift test --filter WorktreeModule` (scan + reclaim) all green.

- [ ] **Step 5: Commit**

```bash
git add Sources/DevSweepCore/Detect/WorktreeModule.swift Tests/DevSweepCoreTests/WorktreeModuleReclaimTests.swift
git commit -m "feat(devsweep): M7 WorktreeModule reclaim (git worktree remove, no --force defense)"
```

---

### Task 6: Cross-module nested suppression + registry wiring

**Files:**
- Create: `Sources/DevSweepCore/Detect/NestedItemSuppressor.swift`
- Modify: `Sources/DevSweepCore/Detect/DetectorRegistry.swift` (apply suppression in `scanGrouped`)
- Create: `Tests/DevSweepCoreTests/NestedItemSuppressorTests.swift`
- Modify: `Tests/DevSweepCoreTests/DetectorRegistryTests.swift` (add a nesting case)

- [ ] **Step 1: Write the failing test**

```swift
// Tests/DevSweepCoreTests/NestedItemSuppressorTests.swift
import Testing
@testable import DevSweepCore

private func item(_ id: String, _ path: String?) -> CleanupItem {
    CleanupItem(id: id, path: path, sizeBytes: 1, lastUsed: nil, safety: .reviewNeeded,
                reclaimMethod: .deletePath(toTrash: false))
}

@Test func suppressesNodeModulesNestedUnderWorktree() {
    let wt = item("/repo/.worktrees/f", "/repo/.worktrees/f")
    let nm = item("/repo/.worktrees/f/node_modules", "/repo/.worktrees/f/node_modules")
    let other = item("/repo/app/node_modules", "/repo/app/node_modules")
    let kept = NestedItemSuppressor.suppressNested([wt, nm, other]).map(\.id)
    #expect(kept.contains("/repo/.worktrees/f"))
    #expect(kept.contains("/repo/app/node_modules"))
    #expect(!kept.contains("/repo/.worktrees/f/node_modules"))   // subsumed by worktree
}

@Test func keepsNilPathItemsAndSiblings() {
    let cli = item("docker:build-cache", nil)
    let a = item("/x/node_modules", "/x/node_modules")
    let b = item("/x-sibling/node_modules", "/x-sibling/node_modules")  // prefix string but not a path child
    let kept = NestedItemSuppressor.suppressNested([cli, a, b]).map(\.id)
    #expect(kept.count == 3)   // nothing nested; "/x" is not a parent dir of "/x-sibling"
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter suppressesNodeModulesNestedUnderWorktree`
Expected: FAIL — `cannot find 'NestedItemSuppressor' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
// Sources/DevSweepCore/Detect/NestedItemSuppressor.swift
import Foundation

/// Cross-module de-dup: when item A's path is an ancestor directory of item B's path, B is
/// removed (A subsumes it). Used so a `git-worktrees` item absorbs `node_modules` items
/// inside it — preventing the same bytes being counted by two modules. Items with no path
/// (CLI-based, e.g. docker) are always kept.
public enum NestedItemSuppressor {
    public static func suppressNested(_ items: [CleanupItem]) -> [CleanupItem] {
        let parents = items.compactMap { $0.path.map(normalize) }
        return items.filter { item in
            guard let p = item.path.map(normalize) else { return true }
            return !parents.contains { parent in parent != p && p.hasPrefix(parent + "/") }
        }
    }
    private static func normalize(_ path: String) -> String { (path as NSString).standardizingPath }
}
```

Wire it into `DetectorRegistry.scanGrouped()` — after `collected` is built and sorted, filter each group to the survivor set:

```swift
// in scanGrouped(), replace the final `return collected.sorted...map...` with:
let sorted = collected.sorted { $0.0 < $1.0 }.map { (module: $0.1, items: $0.2) }
let survivors = Set(NestedItemSuppressor.suppressNested(sorted.flatMap(\.items)).map(\.id))
return sorted
    .map { (module: $0.module, items: $0.items.filter { survivors.contains($0.id) }) }
    .filter { !$0.items.isEmpty }
```

- [ ] **Step 4: Add a registry-level test, then run**

```swift
// Append to Tests/DevSweepCoreTests/DetectorRegistryTests.swift
private struct StubModule: CleanupModule {
    let id: String; let displayName: String; let items: [CleanupItem]
    func isAvailable() async -> Bool { true }
    func scan() async -> [CleanupItem] { items }
    func reclaim(_ items: [CleanupItem], dryRun: Bool) async -> [ReclaimOutcome] { [] }
}

@Test func scanGroupedSuppressesNestedAcrossModules() async {
    let wt = CleanupItem(id: "/r/.worktrees/f", path: "/r/.worktrees/f", sizeBytes: 1, lastUsed: nil,
                         safety: .reviewNeeded, reclaimMethod: .cliCommand(executable: "/usr/bin/env",
                         arguments: ["git", "worktree", "remove", "/r/.worktrees/f"]))
    let nm = CleanupItem(id: "/r/.worktrees/f/node_modules", path: "/r/.worktrees/f/node_modules", sizeBytes: 1,
                         lastUsed: nil, safety: .reviewNeeded, reclaimMethod: .deletePath(toTrash: false))
    let registry = DetectorRegistry(modules: [
        StubModule(id: "git-worktrees", displayName: "Git Worktrees", items: [wt]),
        StubModule(id: "node-modules", displayName: "node_modules", items: [nm])
    ])
    let grouped = await registry.scanGrouped()
    let nodeGroup = grouped.first { $0.module == "node-modules" }
    #expect(nodeGroup == nil)   // its only item was nested under the worktree ⇒ suppressed ⇒ group omitted
}
```

Run: `swift test --filter NestedItemSuppressor` then `swift test --filter scanGroupedSuppressesNestedAcrossModules`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/DevSweepCore/Detect/NestedItemSuppressor.swift Sources/DevSweepCore/Detect/DetectorRegistry.swift \
        Tests/DevSweepCoreTests/NestedItemSuppressorTests.swift Tests/DevSweepCoreTests/DetectorRegistryTests.swift
git commit -m "feat(devsweep): M7 cross-module nested suppression (worktree subsumes node_modules)"
```

---

### Task 7: Register `WorktreeModule` in `DefaultDetectorRegistry`

**Files:**
- Modify: `Sources/DevSweepCore/Detect/DefaultDetectorRegistry.swift`
- Modify: `Tests/DevSweepCoreTests/DefaultDetectorRegistryTests.swift`

- [ ] **Step 1: Update the failing test**

Find the existing assertion on the module set (currently `["docker", "package-cache", "node-modules"]` or a count of 3) and change it to expect 4 including `git-worktrees`:

```swift
// In DefaultDetectorRegistryTests.swift — adjust the expected module ids/count:
#expect(ids == ["docker", "package-cache", "node-modules", "git-worktrees"])
```

(If the existing test asserts a count, change `== 3` to `== 4`. Match whichever form the file uses.)

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter DefaultDetectorRegistry`
Expected: FAIL — module set is still 3 (no `git-worktrees`).

- [ ] **Step 3: Write minimal implementation**

In `makeModules(...)`, construct and append the worktree module (it shares `devRoots`, `commandRunner`, `sizer`):

```swift
let worktrees = WorktreeModule(roots: devRoots, runner: commandRunner, sizer: sizer)

return [docker, packageCache, nodeModules, worktrees]
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter DefaultDetectorRegistry`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/DevSweepCore/Detect/DefaultDetectorRegistry.swift Tests/DevSweepCoreTests/DefaultDetectorRegistryTests.swift
git commit -m "feat(devsweep): M7 register WorktreeModule in default registry"
```

---

### Task 8: Full-suite verification + real-git smoke + UI confirm

**Files:**
- Create: `Tests/DevSweepCoreTests/WorktreeModuleRealGitTests.swift` (one integration test against real git)
- (No UI code: `MenuView` renders module groups generically — confirm by reading it.)

- [ ] **Step 1: Write a real-git integration test (RED)**

```swift
// Tests/DevSweepCoreTests/WorktreeModuleRealGitTests.swift
import Foundation
import Testing
@testable import DevSweepCore

/// End-to-end against real git: a clean worktree on a branch whose commits are all on
/// the default branch (merged) must be a candidate, and `git worktree remove` must reclaim it.
@Test func realGitMergedWorktreeIsCandidateAndRemovable() async throws {
    let runner = ProcessCommandRunner()
    let root = NSTemporaryDirectory() + "devsweep-m7-realgit-\(UInt64.random(in: 0..<999999))"
    let repo = (root as NSString).appendingPathComponent("repo")
    let fm = FileManager.default
    try fm.createDirectory(atPath: repo, withIntermediateDirectories: true)
    func git(_ args: [String]) async throws { _ = try await runner.runResult("/usr/bin/env", ["git", "-C", repo] + args) }
    _ = try await runner.runResult("/usr/bin/env", ["git", "init", "-b", "main", repo])
    try await git(["config", "user.email", "t@t"]); try await git(["config", "user.name", "t"])
    try "x".write(toFile: (repo as NSString).appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
    try await git(["add", "."]); try await git(["commit", "-m", "init"])
    // a branch with NO new commits beyond main ⇒ merged (ancestor) ⇒ candidate
    let wt = (root as NSString).appendingPathComponent("wt")
    try await git(["worktree", "add", wt, "-b", "feat"])

    let module = WorktreeModule(roots: [root], runner: runner)
    let items = await module.scan()
    #expect(items.contains { $0.path == wt })

    let outcomes = await module.reclaim(items.filter { $0.path == wt }, dryRun: false)
    if case .deleted = outcomes.first?.status {} else { Issue.record("expected .deleted; got \(String(describing: outcomes.first?.status))") }
    #expect(fm.fileExists(atPath: wt) == false)
    try? fm.removeItem(atPath: root)
}
```

- [ ] **Step 2: Run it (should pass once Tasks 1–7 are in)**

Run: `swift test --filter realGitMergedWorktreeIsCandidateAndRemovable`
Expected: PASS. (If git treats the brand-new branch as having a remote-tracking gap, the merged ancestor check still classifies it a candidate — no local-only commits beyond main.)

- [ ] **Step 3: Full suite green**

Run: `swift build && swift test`
Expected: all tests pass (prior 205 + new M7 tests), 0 warnings.

- [ ] **Step 4: Confirm UI renders the new group (no code change expected)**

Read `Sources/DevSweepApp/MenuView.swift` and verify it iterates scan groups/modules generically (by `displayName`/module id) rather than hard-coding the three modules. Expected: the new "Git Worktrees" group appears automatically. If MenuView hard-codes module names, add the group following the existing pattern (and note it here) — otherwise no change.

- [ ] **Step 5: Commit**

```bash
git add Tests/DevSweepCoreTests/WorktreeModuleRealGitTests.swift
git commit -m "test(devsweep): M7 real-git worktree integration (scan + remove)"
```

---

## Self-review notes

- **Spec coverage:** §4 discovery → Task 4 `defaultRepoLocator` + inspector. §5 classification gate → Tasks 2–4. §6 reclaim (no `--force`, before/after, dryRun, prune) → Task 5. §7 orphan prune → Tasks 4–5. §8 nested suppression → Task 6. §9 active-check reuse (`ProcessReferenceSignal`) → Task 4. §10 invariants → Tasks 2/5 tests. §12 test cases 1–14 → Tasks 1–8.
- **Type consistency:** `WorktreeMergeLabel`, `WorktreeFacts`, `WorktreeSafetyReason` defined in Task 2 and used unchanged in Tasks 3–4. `reclaimImpl` stub (Task 4) → replaced (Task 5). `fileExists` dependency added in Task 5.
- **Data-loss-0 regression lock:** Task 2 `localOnlyCommitsAreProtected` + Task 3 `inspectorLocalOnlyFailsSafeOnError` + Task 4 `scanProtectsWorktreeWithLocalOnlyCommits` together guarantee an unpushed-commit worktree is never a candidate.

## Out of scope (per spec §13)
Merged local-branch deletion, stale-unpushed review tier, live preview, launchd/crontab activity signals, UI redesign.
