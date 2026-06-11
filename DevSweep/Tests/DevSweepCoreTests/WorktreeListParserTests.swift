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
