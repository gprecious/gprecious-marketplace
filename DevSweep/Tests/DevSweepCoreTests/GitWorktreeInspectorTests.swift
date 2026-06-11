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

@Test func inspectorLocalOnlyFailsSafeOnError() async {  // git error => treat as has-local-only => protected
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
