/// Result of running the Safety Layer on one candidate.
public struct SafetyEvaluation: Sendable, Equatable {
    /// The candidate after evaluation. `safety` is `.protected` if any gate forced it.
    public let item: CleanupItem
    /// Names of the gates/signals that forced protection. Empty if classification was kept.
    public let downgradedBy: [String]

    public init(item: CleanupItem, downgradedBy: [String]) {
        self.item = item
        self.downgradedBy = downgradedBy
    }
}
