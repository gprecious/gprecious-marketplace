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
