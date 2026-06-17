import Foundation
import Testing
@testable import DevSweepCore

private func emptyLayerReclaimer(_ deleter: any FileSystemDeleter) -> Reclaimer {
    Reclaimer(safety: SafetyLayer(signals: [], registry: ProtectedRegistry(userExcluded: [], systemProtected: [])),
              deleter: deleter)
}

@Test func packageCacheDefaultToolsHaveFiveEntries() {
    let tools = PackageCacheModule.defaultTools(home: "/Users/x")
    #expect(tools.map(\.id) == ["pnpm", "npm", "uv", "bun", "gradle"])
    // gradle is the only path-delete fallback
    if case .deletePath = tools.last!.reclaim {} else { Issue.record("gradle must be deletePath") }
}

@Test func packageCacheScanEmitsOnlyAvailableCliTools() async {
    let tmp = TempDir(); defer { tmp.cleanup() }
    let pnpmCache = tmp.makeDir("pnpm-store")
    let runner = ScriptedCommandRunner([
        "/usr/bin/env pnpm --version": [.init(stdout: "9.0.0", exitCode: 0)],
        "/usr/bin/env npm --version": [.init(exitCode: 127)]  // not installed
    ])
    let tools: [PackageCacheModule.Tool] = [
        .init(id: "pnpm", probe: .cli(executable: "/usr/bin/env", arguments: ["pnpm", "--version"]),
              cachePath: pnpmCache, reclaim: .cliCommand(executable: "/usr/bin/env", arguments: ["pnpm", "store", "prune"])),
        .init(id: "npm", probe: .cli(executable: "/usr/bin/env", arguments: ["npm", "--version"]),
              cachePath: tmp.url.appendingPathComponent("npm").path,
              reclaim: .cliCommand(executable: "/usr/bin/env", arguments: ["npm", "cache", "clean", "--force"]))
    ]
    let module = PackageCacheModule(tools: tools, runner: runner, reclaimer: emptyLayerReclaimer(RecordingDeleter()))
    let items = await module.scan()
    #expect(items.map(\.id) == ["package-cache:pnpm"])
    #expect(items.first?.safety == .autoSafe)
    #expect(items.first?.path == nil)  // CLI item → path nil
}

@Test func packageCacheGradleAvailableWhenCacheDirExists() async {
    let tmp = TempDir(); defer { tmp.cleanup() }
    let gradleCache = tmp.makeDir("gradle-caches")
    let tools: [PackageCacheModule.Tool] = [
        .init(id: "gradle", probe: .pathExists, cachePath: gradleCache, reclaim: .deletePath(toTrash: false))
    ]
    let module = PackageCacheModule(tools: tools, runner: ScriptedCommandRunner([:]),
                                    reclaimer: emptyLayerReclaimer(RecordingDeleter()))
    #expect(await module.isAvailable() == true)
    let items = await module.scan()
    #expect(items.map(\.id) == ["package-cache:gradle"])
    #expect(items.first?.path == gradleCache)  // deletePath item → path set
}

@Test func packageCacheScanBoundsCacheSizingDuringDetection() async {
    let tmp = TempDir(); defer { tmp.cleanup() }
    let pnpmCache = tmp.makeDir("pnpm-store")
    tmp.writeFile("pnpm-store/a.txt", String(repeating: "a", count: 10))
    tmp.writeFile("pnpm-store/b.txt", String(repeating: "b", count: 10))
    tmp.writeFile("pnpm-store/c.txt", String(repeating: "c", count: 10))
    let runner = ScriptedCommandRunner([
        "/usr/bin/env pnpm --version": [.init(stdout: "9", exitCode: 0)]
    ])
    let tools: [PackageCacheModule.Tool] = [
        .init(id: "pnpm", probe: .cli(executable: "/usr/bin/env", arguments: ["pnpm", "--version"]),
              cachePath: pnpmCache, reclaim: .cliCommand(executable: "/usr/bin/env", arguments: ["pnpm", "store", "prune"]))
    ]
    let module = PackageCacheModule(
        tools: tools,
        runner: runner,
        reclaimer: emptyLayerReclaimer(RecordingDeleter()),
        scanSizeDescendantLimit: 2
    )

    let items = await module.scan()

    #expect(items.count == 1)
    #expect(items[0].sizeBytes == 20)
}

@Test func packageCacheScanDefaultReportsNonZeroForNonEmptyCache() async {
    let tmp = TempDir(); defer { tmp.cleanup() }
    let pnpmCache = tmp.makeDir("pnpm-store")
    tmp.writeFile("pnpm-store/payload.txt", String(repeating: "x", count: 10))
    let runner = ScriptedCommandRunner([
        "/usr/bin/env pnpm --version": [.init(stdout: "9", exitCode: 0)]
    ])
    let tools: [PackageCacheModule.Tool] = [
        .init(id: "pnpm", probe: .cli(executable: "/usr/bin/env", arguments: ["pnpm", "--version"]),
              cachePath: pnpmCache, reclaim: .cliCommand(executable: "/usr/bin/env", arguments: ["pnpm", "store", "prune"]))
    ]
    let module = PackageCacheModule(tools: tools, runner: runner, reclaimer: emptyLayerReclaimer(RecordingDeleter()))

    let items = await module.scan()

    #expect(items.count == 1)
    #expect(items[0].sizeBytes > 0)
}

@Test func packageCacheGradleUnavailableWhenCacheMissing() async {
    let tools: [PackageCacheModule.Tool] = [
        .init(id: "gradle", probe: .pathExists, cachePath: "/nope/gradle", reclaim: .deletePath(toTrash: false))
    ]
    let module = PackageCacheModule(tools: tools, runner: ScriptedCommandRunner([:]),
                                    reclaimer: emptyLayerReclaimer(RecordingDeleter()))
    #expect(await module.isAvailable() == false)
    #expect(await module.scan().isEmpty)
}

@Test func packageCacheGradleReclaimDelegatesToM1Reclaimer() async {
    let tmp = TempDir(); defer { tmp.cleanup() }
    let gradleCache = tmp.makeDir("gradle-caches")
    let deleter = RecordingDeleter(bytesPerCall: 4096)
    let tools: [PackageCacheModule.Tool] = [
        .init(id: "gradle", probe: .pathExists, cachePath: gradleCache, reclaim: .deletePath(toTrash: false))
    ]
    let module = PackageCacheModule(tools: tools, runner: ScriptedCommandRunner([:]),
                                    reclaimer: emptyLayerReclaimer(deleter))
    let items = await module.scan()
    let outcomes = await module.reclaim(items, dryRun: false)
    #expect(outcomes.first?.status == .deleted(bytes: 4096))
    #expect(await deleter.calls.first == .init(path: gradleCache, toTrash: false))
}

@Test func packageCacheCliReclaimRunsCommandAndReportsDeleted() async {
    let tmp = TempDir(); defer { tmp.cleanup() }
    let pnpmCache = tmp.makeDir("pnpm-store")
    let runner = ScriptedCommandRunner([
        "/usr/bin/env pnpm --version": [.init(stdout: "9", exitCode: 0)],
        "/usr/bin/env pnpm store prune": [.init(stdout: "removed", exitCode: 0)]
    ])
    let tools: [PackageCacheModule.Tool] = [
        .init(id: "pnpm", probe: .cli(executable: "/usr/bin/env", arguments: ["pnpm", "--version"]),
              cachePath: pnpmCache, reclaim: .cliCommand(executable: "/usr/bin/env", arguments: ["pnpm", "store", "prune"]))
    ]
    let module = PackageCacheModule(tools: tools, runner: runner, reclaimer: emptyLayerReclaimer(RecordingDeleter()))
    let items = await module.scan()
    let outcomes = await module.reclaim(items, dryRun: false)
    if case .deleted = outcomes.first?.status {} else { Issue.record("expected .deleted for cli prune") }
    #expect(await runner.calls.contains("/usr/bin/env pnpm store prune"))
}

@Test func packageCacheCliReclaimFailsOnNonZeroExit() async {
    let tmp = TempDir(); defer { tmp.cleanup() }
    let runner = ScriptedCommandRunner([
        "/usr/bin/env uv cache clean": [.init(stdout: "boom", exitCode: 2)]
    ])
    let item = CleanupItem(id: "package-cache:uv", path: nil, sizeBytes: 10, lastUsed: nil, safety: .autoSafe,
                           reclaimMethod: .cliCommand(executable: "/usr/bin/env", arguments: ["uv", "cache", "clean"]))
    let tools: [PackageCacheModule.Tool] = [
        .init(id: "uv", probe: .cli(executable: "/usr/bin/env", arguments: ["uv", "--version"]),
              cachePath: tmp.url.appendingPathComponent("uv").path,
              reclaim: .cliCommand(executable: "/usr/bin/env", arguments: ["uv", "cache", "clean"]))
    ]
    let module = PackageCacheModule(tools: tools, runner: runner, reclaimer: emptyLayerReclaimer(RecordingDeleter()))
    let outcomes = await module.reclaim([item], dryRun: false)
    if case .failed = outcomes.first?.status {} else { Issue.record("expected .failed on exit 2") }
}
