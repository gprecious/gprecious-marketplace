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
    // Real temp dir for sizing; stub fileExists => false (gone) so we don't depend on git actually removing it.
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
    // Defense: git returned 0 but path remains => failure, not a false "deleted".
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
