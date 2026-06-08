import Foundation
import Testing
@testable import DevSweepCore

private let dfJSON = """
{"Type":"Images","TotalCount":"10","Active":"3","Size":"5GB","Reclaimable":"2GB (40%)"}
{"Type":"Containers","TotalCount":"2","Active":"1","Size":"100MB","Reclaimable":"50MB (50%)"}
{"Type":"Local Volumes","TotalCount":"4","Active":"4","Size":"1GB","Reclaimable":"0B (0%)"}
{"Type":"Build Cache","TotalCount":"20","Active":"0","Size":"3GB","Reclaimable":"3GB"}
"""

private let dfAfterJSON = """
{"Type":"Images","TotalCount":"10","Active":"3","Size":"5GB","Reclaimable":"2GB (40%)"}
{"Type":"Build Cache","TotalCount":"0","Active":"0","Size":"1GB","Reclaimable":"1GB"}
"""

@Test func dockerUnavailableWhenSystemDfFails() async {
    let runner = ScriptedCommandRunner([
        "/usr/bin/env docker system df": [.init(exitCode: 1)]
    ])
    let module = DockerModule(runner: runner)
    #expect(await module.isAvailable() == false)
}

@Test func dockerScanEmitsThreeSafetyClassedActionsNeverVolumes() async {
    let runner = ScriptedCommandRunner([
        "/usr/bin/env docker system df --format {{json .}}": [.init(stdout: dfJSON)]
    ])
    let module = DockerModule(runner: runner)
    let items = await module.scan()

    #expect(items.map(\.id) == ["docker:build-cache", "docker:dangling-images", "docker:unused-images"])
    #expect(items[0].safety == .autoSafe)
    #expect(items[1].safety == .autoSafe)
    #expect(items[2].safety == .reviewNeeded)
    #expect(items.allSatisfy { $0.path == nil })

    // sizes parsed from df Reclaimable (base-1000): build cache 3GB, unused images 2GB.
    #expect(items[0].sizeBytes == 3_000_000_000)
    #expect(items[2].sizeBytes == 2_000_000_000)

    // NO --volumes anywhere.
    for item in items {
        if case let .cliCommand(_, args) = item.reclaimMethod {
            #expect(!args.contains("--volumes"))
        } else {
            Issue.record("docker items must be cliCommand")
        }
    }
    // exact commands
    if case let .cliCommand(_, a0) = items[0].reclaimMethod { #expect(a0 == ["docker", "builder", "prune", "-f"]) }
    if case let .cliCommand(_, a1) = items[1].reclaimMethod { #expect(a1 == ["docker", "image", "prune", "-f"]) }
    if case let .cliCommand(_, a2) = items[2].reclaimMethod { #expect(a2 == ["docker", "image", "prune", "-a", "-f"]) }
}

@Test func dockerReclaimMeasuresBeforeAfterDelta() async {
    // before total Size = 5GB+100MB+1GB+3GB = 9.1e9 ; after = 5GB+1GB = 6e9 ; delta = 3.1e9
    let runner = ScriptedCommandRunner([
        "/usr/bin/env docker system df --format {{json .}}": [
            .init(stdout: dfJSON),       // before
            .init(stdout: dfAfterJSON)   // after
        ],
        "/usr/bin/env docker builder prune -f": [.init(stdout: "deleted", exitCode: 0)]
    ])
    let module = DockerModule(runner: runner)
    let item = CleanupItem(id: "docker:build-cache", path: nil, sizeBytes: 3_000_000_000, lastUsed: nil,
                           safety: .autoSafe,
                           reclaimMethod: .cliCommand(executable: "/usr/bin/env",
                                                      arguments: ["docker", "builder", "prune", "-f"]))
    let outcomes = await module.reclaim([item], dryRun: false)
    #expect(outcomes.first?.status == .deleted(bytes: 3_100_000_000))
}

@Test func dockerReclaimDryRunDoesNotRunPrune() async {
    let runner = ScriptedCommandRunner([:])
    let module = DockerModule(runner: runner)
    let item = CleanupItem(id: "docker:build-cache", path: nil, sizeBytes: 999, lastUsed: nil,
                           safety: .autoSafe,
                           reclaimMethod: .cliCommand(executable: "/usr/bin/env",
                                                      arguments: ["docker", "builder", "prune", "-f"]))
    let outcomes = await module.reclaim([item], dryRun: true)
    #expect(outcomes.first?.status == .dryRun(plannedBytes: 999))
    #expect(await runner.callCount == 0)
}

@Test func dockerReclaimFailsOnNonZeroExit() async {
    let runner = ScriptedCommandRunner([
        "/usr/bin/env docker system df --format {{json .}}": [.init(stdout: dfJSON), .init(stdout: dfJSON)],
        "/usr/bin/env docker image prune -a -f": [.init(stdout: "err", exitCode: 1)]
    ])
    let module = DockerModule(runner: runner)
    let item = CleanupItem(id: "docker:unused-images", path: nil, sizeBytes: 0, lastUsed: nil,
                           safety: .reviewNeeded,
                           reclaimMethod: .cliCommand(executable: "/usr/bin/env",
                                                      arguments: ["docker", "image", "prune", "-a", "-f"]))
    let outcomes = await module.reclaim([item], dryRun: false)
    if case .failed = outcomes.first?.status {} else { Issue.record("expected .failed on exit 1") }
}

@Test func dockerReclaimRefusesVolumesCommand() async {
    let runner = ScriptedCommandRunner([:])
    let module = DockerModule(runner: runner)
    let evil = CleanupItem(id: "docker:evil", path: nil, sizeBytes: 0, lastUsed: nil,
                           safety: .autoSafe,
                           reclaimMethod: .cliCommand(executable: "/usr/bin/env",
                                                      arguments: ["docker", "system", "prune", "--volumes", "-f"]))
    let outcomes = await module.reclaim([evil], dryRun: false)
    if case let .failed(msg) = outcomes.first?.status { #expect(msg.contains("--volumes")) }
    else { Issue.record("expected .failed refusing --volumes") }
    #expect(await runner.callCount == 0)
}
