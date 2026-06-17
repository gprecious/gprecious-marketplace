import Testing
@testable import DevSweepCore

private func summaryItem(_ id: String, bytes: Int64) -> CleanupItem {
    CleanupItem(
        id: id,
        path: nil,
        sizeBytes: bytes,
        lastUsed: nil,
        safety: .reviewNeeded,
        reclaimMethod: .cliCommand(executable: "x", arguments: [])
    )
}

@Test func dryRunSummaryCountsPlannedProtectedAndFailedOutcomes() {
    let outcomes = [
        ReclaimOutcome(item: summaryItem("docker:build", bytes: 10), status: .dryRun(plannedBytes: 10)),
        ReclaimOutcome(item: summaryItem("cache:npm", bytes: 20), status: .dryRun(plannedBytes: 20)),
        ReclaimOutcome(item: summaryItem("/active/node_modules", bytes: 30), status: .skippedProtected),
        ReclaimOutcome(item: summaryItem("broken", bytes: 40), status: .failed(message: "no owning module"))
    ]

    let summary = ReclaimRunSummary(kind: .dryRun, outcomes: outcomes)

    #expect(summary.kind == .dryRun)
    #expect(summary.totalCount == 4)
    #expect(summary.actionCount == 2)
    #expect(summary.plannedBytes == 30)
    #expect(summary.reclaimedBytes == 0)
    #expect(summary.protectedCount == 1)
    #expect(summary.failedCount == 1)
}

@Test func liveSummaryCountsDeletedBytesSeparatelyFromDryRunPlans() {
    let outcomes = [
        ReclaimOutcome(item: summaryItem("docker:build", bytes: 10), status: .deleted(bytes: 7)),
        ReclaimOutcome(item: summaryItem("cache:npm", bytes: 20), status: .dryRun(plannedBytes: 20)),
        ReclaimOutcome(item: summaryItem("protected", bytes: 30), status: .skippedProtected)
    ]

    let summary = ReclaimRunSummary(kind: .live, outcomes: outcomes)

    #expect(summary.kind == .live)
    #expect(summary.totalCount == 3)
    #expect(summary.actionCount == 1)
    #expect(summary.plannedBytes == 20)
    #expect(summary.reclaimedBytes == 7)
    #expect(summary.protectedCount == 1)
    #expect(summary.failedCount == 0)
}
