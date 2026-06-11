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
