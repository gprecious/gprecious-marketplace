import Foundation
import Testing
@testable import DevSweepCore

private func pathItem(_ path: String, _ safety: SafetyClass = .reviewNeeded) -> CleanupItem {
    CleanupItem(id: path, path: path, sizeBytes: 1_000, lastUsed: nil,
                safety: safety, reclaimMethod: .deletePath(toTrash: false))
}

@Test func dryRunNeverCallsDeleter() async {
    let deleter = RecordingDeleter(bytesPerCall: 1_000)
    let layer = SafetyLayer(signals: [], registry: ProtectedRegistry(userExcluded: [], systemProtected: []))
    let reclaimer = Reclaimer(safety: layer, deleter: deleter)

    let outcomes = await reclaimer.reclaim([pathItem("/Users/x/a"), pathItem("/Users/x/b")], dryRun: true)

    #expect(await deleter.callCount == 0)
    #expect(outcomes.count == 2)
    for outcome in outcomes {
        #expect(outcome.status == .dryRun(plannedBytes: 1_000))
    }
}

@Test func protectedItemIsNeverDeletedEvenWhenNotDryRun() async {
    let deleter = RecordingDeleter(bytesPerCall: 1_000)
    // Active signal downgrades the path to .protected.
    let layer = SafetyLayer(
        signals: [MockActivitySignal(name: "process", activePaths: ["/Users/x/inuse"])],
        registry: ProtectedRegistry(userExcluded: [], systemProtected: [])
    )
    let reclaimer = Reclaimer(safety: layer, deleter: deleter)

    let outcomes = await reclaimer.reclaim([pathItem("/Users/x/inuse")], dryRun: false)

    #expect(await deleter.callCount == 0)
    #expect(outcomes.first?.status == .skippedProtected)
}

@Test func nonProtectedItemIsDeletedWhenNotDryRun() async {
    let deleter = RecordingDeleter(bytesPerCall: 2_048)
    let layer = SafetyLayer(signals: [], registry: ProtectedRegistry(userExcluded: [], systemProtected: []))
    let reclaimer = Reclaimer(safety: layer, deleter: deleter)

    let outcomes = await reclaimer.reclaim([pathItem("/Users/x/cache")], dryRun: false)

    #expect(await deleter.callCount == 1)
    #expect(await deleter.calls.first == .init(path: "/Users/x/cache", toTrash: false))
    #expect(outcomes.first?.status == .deleted(bytes: 2_048))
}
