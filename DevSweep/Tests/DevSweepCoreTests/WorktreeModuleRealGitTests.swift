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
    // a branch with NO new commits beyond main => merged (ancestor) => candidate
    let wt = (root as NSString).appendingPathComponent("wt")
    try await git(["worktree", "add", wt, "-b", "feat"])
    let listedWt = await GitWorktreeInspector(runner: runner)
        .worktrees(inRepo: repo)
        .first { !$0.isMain }?
        .path
    guard let listedWt else {
        Issue.record("expected git to list linked worktree")
        return
    }

    let module = WorktreeModule(roots: [root], runner: runner)
    let items = await module.scan()
    #expect(items.contains { $0.path == listedWt })

    let outcomes = await module.reclaim(items.filter { $0.path == listedWt }, dryRun: false)
    if case .deleted = outcomes.first?.status {} else { Issue.record("expected .deleted; got \(String(describing: outcomes.first?.status))") }
    #expect(fm.fileExists(atPath: wt) == false)
    try? fm.removeItem(atPath: root)
}
