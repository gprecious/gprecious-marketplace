import Foundation
import Testing
@testable import DevSweepCore

@Test func defaultRegistryComposesThreeRealModuleTypesDeterministically() async {
    // Docker unavailable (df exit 1), no package tools available, no dev roots → empty scan,
    // but the registry is built from the real module types without crashing.
    // NOTE: package-manager CLIs must be scripted to fail (exit 127 = command-not-found).
    // ScriptedCommandRunner returns exit 0 for UNSCRIPTED commands, which the real
    // PackageCacheModule treats as "tool installed" — so an unscripted probe would
    // spuriously surface package-cache. Scripting them as absent encodes the test's intent.
    let runner = ScriptedCommandRunner([
        "/usr/bin/env docker system df": [.init(exitCode: 1)],
        "/usr/bin/env pnpm --version": [.init(exitCode: 127)],
        "/usr/bin/env npm --version": [.init(exitCode: 127)],
        "/usr/bin/env uv --version": [.init(exitCode: 127)],
        "/usr/bin/env bun --version": [.init(exitCode: 127)]
    ])
    let registry = DefaultDetectorRegistry.make(
        home: "/nonexistent-home",
        devRoots: [],
        commandRunner: runner,
        deleter: RecordingDeleter()
    )
    #expect(await registry.scanAll().isEmpty)
}

@Test func defaultRegistrySurfacesAvailableDockerOnly() async {
    let df = """
    {"Type":"Build Cache","TotalCount":"5","Active":"0","Size":"2GB","Reclaimable":"2GB"}
    """
    // Package CLIs scripted absent (see note above) so only docker surfaces.
    let runner = ScriptedCommandRunner([
        "/usr/bin/env docker system df": [.init(exitCode: 0)],
        "/usr/bin/env docker system df --format {{json .}}": [.init(stdout: df)],
        "/usr/bin/env pnpm --version": [.init(exitCode: 127)],
        "/usr/bin/env npm --version": [.init(exitCode: 127)],
        "/usr/bin/env uv --version": [.init(exitCode: 127)],
        "/usr/bin/env bun --version": [.init(exitCode: 127)]
    ])
    let registry = DefaultDetectorRegistry.make(
        home: "/nonexistent-home",
        devRoots: [],
        commandRunner: runner,
        deleter: RecordingDeleter()
    )
    let grouped = await registry.scanGrouped()
    #expect(grouped.map(\.module) == ["docker"])
    #expect(grouped.first?.items.contains { $0.id == "docker:build-cache" } == true)
}
