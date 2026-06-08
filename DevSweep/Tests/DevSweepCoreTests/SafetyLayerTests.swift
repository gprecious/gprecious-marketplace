import Foundation
import Testing
@testable import DevSweepCore

private func candidate(_ path: String, _ safety: SafetyClass = .reviewNeeded) -> CleanupItem {
    CleanupItem(id: path, path: path, sizeBytes: 4_700_000_000, lastUsed: nil,
                safety: safety, reclaimMethod: .deletePath(toTrash: false))
}

@Test func noSignalsKeepsOriginalClassification() async {
    let layer = SafetyLayer(signals: [], registry: ProtectedRegistry(userExcluded: [], systemProtected: []))
    let eval = await layer.evaluate(candidate("/Users/x/.npm", .autoSafe))
    #expect(eval.item.safety == .autoSafe)
    #expect(eval.downgradedBy.isEmpty)
}

@Test func protectedRegistryForcesProtection() async {
    let layer = SafetyLayer(
        signals: [MockActivitySignal(name: "process", activePaths: [])],
        registry: ProtectedRegistry(userExcluded: ["/Users/x/.ssh"], systemProtected: [])
    )
    let eval = await layer.evaluate(candidate("/Users/x/.ssh"))
    #expect(eval.item.safety == .protected)
    #expect(eval.downgradedBy == ["protected-registry"])
}

@Test func anyActiveSignalDowngradesToProtected() async {
    let layer = SafetyLayer(
        signals: [MockActivitySignal(name: "process", activePaths: ["/Users/x/app"])],
        registry: ProtectedRegistry(userExcluded: [], systemProtected: [])
    )
    let eval = await layer.evaluate(candidate("/Users/x/app"))
    #expect(eval.item.safety == .protected)
    #expect(eval.downgradedBy == ["process"])
}

/// THE pyiri REGRESSION. A 4.7GB candidate that three independent signals report as
/// active (process on port, launchd KeepAlive, crontab reference) MUST be downgraded
/// to .protected and never offered for deletion. If this test ever fails, the build fails.
@Test func pyiriScenarioIsProtectedByMultipleSignals() async {
    let pyiri = "/Users/x/.openclaw-pyiri"
    let layer = SafetyLayer(
        signals: [
            MockActivitySignal(name: "process", activePaths: [pyiri]),
            MockActivitySignal(name: "launchd", activePaths: [pyiri]),
            MockActivitySignal(name: "crontab", activePaths: [pyiri]),
            MockActivitySignal(name: "recent-use", activePaths: [pyiri]),
            MockActivitySignal(name: "parent-project", activePaths: [])
        ],
        registry: ProtectedRegistry(userExcluded: [], systemProtected: [])
    )
    let eval = await layer.evaluate(candidate(pyiri, .reviewNeeded))
    #expect(eval.item.safety == .protected)
    #expect(eval.downgradedBy.contains("process"))
    #expect(eval.downgradedBy.contains("launchd"))
    #expect(eval.downgradedBy.contains("crontab"))
}

@Test func nilPathItemSkipsActiveCheck() async {
    // CLI-based items (path == nil) have no filesystem path to check; they keep classification.
    let layer = SafetyLayer(
        signals: [MockActivitySignal(name: "process", activePaths: [])],
        registry: ProtectedRegistry(userExcluded: [], systemProtected: [])
    )
    let cli = CleanupItem(id: "docker:buildcache", path: nil, sizeBytes: 14_000_000_000,
                          lastUsed: nil, safety: .autoSafe,
                          reclaimMethod: .cliCommand(executable: "docker", arguments: ["builder", "prune", "-a", "-f"]))
    let eval = await layer.evaluate(cli)
    #expect(eval.item.safety == .autoSafe)
    #expect(eval.downgradedBy.isEmpty)
}
