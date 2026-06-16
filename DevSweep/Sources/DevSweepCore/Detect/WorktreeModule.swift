import Foundation

/// 4th CleanupModule: reclaims merged/clean git worktrees as a unit via `git worktree remove`.
/// CLI-reclaim (like DockerModule). Data-loss-0: only clean + unlocked + fully-pushed + inactive
/// worktrees are emitted (as `.reviewNeeded`); everything else is protected (not shown).
public struct WorktreeModule: CleanupModule, @unchecked Sendable {
    public let id = "git-worktrees"
    public let displayName = "Git Worktrees"
    public static let defaultScanSizeDescendantLimit = DirectorySizer.defaultScanDescendantLimit

    private let roots: [String]
    private let runner: any CommandRunner
    private let inspector: GitWorktreeInspector
    private let sizer: DirectorySizer
    private let scanSizeDescendantLimit: Int?
    private let activitySignal: any ActivitySignal
    private let repoLocator: @Sendable ([String]) -> [String]
    private let executable: String
    private let argPrefix: [String]
    private let fileExists: @Sendable (String) -> Bool

    public init(roots: [String],
                runner: any CommandRunner,
                sizer: DirectorySizer = DirectorySizer(),
                activitySignal: (any ActivitySignal)? = nil,
                repoLocator: (@Sendable ([String]) -> [String])? = nil,
                scanSizeDescendantLimit: Int? = Self.defaultScanSizeDescendantLimit,
                executable: String = "/usr/bin/env",
                argPrefix: [String] = ["git"],
                fileExists: (@Sendable (String) -> Bool)? = nil) {
        self.roots = roots
        self.runner = runner
        self.inspector = GitWorktreeInspector(runner: runner, executable: executable, argPrefix: argPrefix)
        self.sizer = sizer
        self.scanSizeDescendantLimit = scanSizeDescendantLimit
        self.activitySignal = activitySignal ?? ProcessReferenceSignal(runner: runner)
        self.repoLocator = repoLocator ?? Self.defaultRepoLocator
        self.executable = executable
        self.argPrefix = argPrefix
        self.fileExists = fileExists ?? { FileManager.default.fileExists(atPath: $0) }
    }

    public func isAvailable() async -> Bool {
        guard let r = try? await runner.runResult(executable, argPrefix + ["--version"]) else { return false }
        return r.exitCode == 0
    }

    public func scan() async -> [CleanupItem] {
        var items: [CleanupItem] = []
        for repo in repoLocator(roots) {
            let entries = await inspector.worktrees(inRepo: repo)
            guard entries.count > 1 else { continue }   // main only => nothing to reclaim
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
                    sizeBytes: sizer.size(of: entry.path, maxDescendantEntries: scanSizeDescendantLimit), lastUsed: nil,
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
