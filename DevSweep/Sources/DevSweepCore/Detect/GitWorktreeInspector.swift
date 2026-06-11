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
        guard let r = await run(["-C", path, "status", "--porcelain"]) else { return true } // fail-safe => protected
        return !r.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// True if any commit reachable from `head` is on neither a remote nor `defaultBranch`.
    /// Fail-safe: git error => true (treat as local work present => protected).
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
