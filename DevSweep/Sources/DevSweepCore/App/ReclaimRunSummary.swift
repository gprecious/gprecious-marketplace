public enum ReclaimRunKind: Sendable, Equatable {
    case dryRun
    case live
}

public struct ReclaimRunSummary: Sendable, Equatable {
    public let kind: ReclaimRunKind
    public let totalCount: Int
    public let actionCount: Int
    public let plannedBytes: Int64
    public let reclaimedBytes: Int64
    public let protectedCount: Int
    public let failedCount: Int

    public init(kind: ReclaimRunKind, outcomes: [ReclaimOutcome]) {
        var actionCount = 0
        var plannedBytes: Int64 = 0
        var reclaimedBytes: Int64 = 0
        var protectedCount = 0
        var failedCount = 0

        for outcome in outcomes {
            switch outcome.status {
            case .dryRun(let bytes):
                if kind == .dryRun {
                    actionCount += 1
                }
                plannedBytes += bytes
            case .deleted(let bytes):
                if kind == .live {
                    actionCount += 1
                }
                reclaimedBytes += bytes
            case .skippedProtected:
                protectedCount += 1
            case .failed:
                failedCount += 1
            }
        }

        self.kind = kind
        self.totalCount = outcomes.count
        self.actionCount = actionCount
        self.plannedBytes = plannedBytes
        self.reclaimedBytes = reclaimedBytes
        self.protectedCount = protectedCount
        self.failedCount = failedCount
    }
}
