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
    #expect(await module.scan().isEmpty)   // protected => not emitted
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

@Test func scanBoundsWorktreeSizingDuringDetection() async {
    let tmp = TempDir(); defer { tmp.cleanup() }
    let repo = tmp.makeDir("repo")
    tmp.writeFile("repo/.worktrees/cand/a.txt", String(repeating: "a", count: 10))
    tmp.writeFile("repo/.worktrees/cand/b.txt", String(repeating: "b", count: 10))
    tmp.writeFile("repo/.worktrees/cand/c.txt", String(repeating: "c", count: 10))
    let runner = makeRunner(repo: repo)
    let module = WorktreeModule(
        roots: [],
        runner: runner,
        activitySignal: InactiveSignal(),
        repoLocator: { _ in [repo] },
        scanSizeDescendantLimit: 2
    )

    let items = await module.scan()

    #expect(items.count == 1)
    #expect(items[0].sizeBytes == 20)
}

@Test func scanDefaultReportsNonZeroForNonEmptyWorktree() async {
    let tmp = TempDir(); defer { tmp.cleanup() }
    let repo = tmp.makeDir("repo")
    tmp.writeFile("repo/.worktrees/cand/payload.txt", String(repeating: "x", count: 10))
    let runner = makeRunner(repo: repo)
    let module = WorktreeModule(
        roots: [],
        runner: runner,
        activitySignal: InactiveSignal(),
        repoLocator: { _ in [repo] }
    )

    let items = await module.scan()

    #expect(items.count == 1)
    #expect(items[0].sizeBytes > 0)
}

@Test func scanUnavailableWhenGitMissing() async {
    let runner = ScriptedCommandRunner(["/usr/bin/env git --version": [.init(exitCode: 127)]])
    let module = WorktreeModule(roots: [], runner: runner, activitySignal: InactiveSignal(), repoLocator: { _ in [] })
    #expect(await module.isAvailable() == false)
}
