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
