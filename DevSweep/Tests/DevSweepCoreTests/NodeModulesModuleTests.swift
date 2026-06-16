import Foundation
import Testing
@testable import DevSweepCore

private func emptyLayerReclaimer(_ deleter: any FileSystemDeleter) -> Reclaimer {
    Reclaimer(safety: SafetyLayer(signals: [], registry: ProtectedRegistry(userExcluded: [], systemProtected: [])),
              deleter: deleter)
}

@Test func nodeModulesScanFindsTargetsAndExcludesProtectedProjects() async {
    let tmp = TempDir(); defer { tmp.cleanup() }
    tmp.makeDir("alpha/node_modules")
    tmp.makeDir("beta/.venv")
    tmp.makeDir("gprecious-marketplace/node_modules")  // excluded by name
    let module = NodeModulesModule(roots: [tmp.url.path], reclaimer: emptyLayerReclaimer(RecordingDeleter()))
    let ids = Set(await module.scan().map { ($0.path! as NSString).lastPathComponent + "@" + (($0.path! as NSString).deletingLastPathComponent as NSString).lastPathComponent })
    #expect(ids.contains("node_modules@alpha"))
    #expect(ids.contains(".venv@beta"))
    #expect(!ids.contains("node_modules@gprecious-marketplace"))
}

@Test func nodeModulesDoesNotDescendIntoTargetDir() async {
    let tmp = TempDir(); defer { tmp.cleanup() }
    tmp.makeDir("proj/node_modules/nested/node_modules")  // nested must NOT be emitted
    let module = NodeModulesModule(roots: [tmp.url.path], reclaimer: emptyLayerReclaimer(RecordingDeleter()))
    let items = await module.scan()
    #expect(items.count == 1)
    #expect((items.first!.path! as NSString).lastPathComponent == "node_modules")
}

@Test func nodeModulesItemsAreReviewNeededDeletePath() async {
    let tmp = TempDir(); defer { tmp.cleanup() }
    tmp.makeDir("proj/node_modules")
    let module = NodeModulesModule(roots: [tmp.url.path], reclaimer: emptyLayerReclaimer(RecordingDeleter()))
    let item = await module.scan().first!
    #expect(item.safety == .reviewNeeded)
    #expect(item.reclaimMethod == .deletePath(toTrash: false))
}

@Test func nodeModulesScanBoundsTargetSizingDuringDetection() async {
    let tmp = TempDir(); defer { tmp.cleanup() }
    tmp.writeFile("proj/node_modules/a.txt", String(repeating: "a", count: 10))
    tmp.writeFile("proj/node_modules/b.txt", String(repeating: "b", count: 10))
    tmp.writeFile("proj/node_modules/c.txt", String(repeating: "c", count: 10))
    let module = NodeModulesModule(
        roots: [tmp.url.path],
        reclaimer: emptyLayerReclaimer(RecordingDeleter()),
        scanSizeDescendantLimit: 2
    )

    let item = await module.scan().first!

    #expect(item.sizeBytes == 20)
}

@Test func nodeModulesReclaimDeletesWhenLayerHasNoSignals() async {
    let tmp = TempDir(); defer { tmp.cleanup() }
    tmp.makeDir("proj/node_modules")
    let deleter = RecordingDeleter(bytesPerCall: 8192)
    let module = NodeModulesModule(roots: [tmp.url.path], reclaimer: emptyLayerReclaimer(deleter))
    let outcomes = await module.reclaim(await module.scan(), dryRun: false)
    #expect(outcomes.first?.status == .deleted(bytes: 8192))
    #expect(await deleter.callCount == 1)
}

// MARK: - Real-machine robustness (symlink cycles, build-dir pruning, depth bound)

/// A self-referential symlink (`proj/loop -> proj`) would make a link-following walk recurse
/// forever (stack overflow on the real dev tree, which has 13k+ symlinks). The walk must skip
/// symlinks entirely and return.
@Test func nodeModulesDoesNotFollowSymlinkCycles() async throws {
    let tmp = TempDir(); defer { tmp.cleanup() }
    tmp.makeDir("proj/node_modules")
    let projPath = (tmp.url.path as NSString).appendingPathComponent("proj")
    let linkPath = (projPath as NSString).appendingPathComponent("loop")
    try FileManager.default.createSymbolicLink(atPath: linkPath, withDestinationPath: projPath)

    let module = NodeModulesModule(roots: [tmp.url.path], reclaimer: emptyLayerReclaimer(RecordingDeleter()))
    let items = await module.scan() // must return — no hang, no stack overflow

    #expect(items.count == 1)
    #expect((items.first!.path! as NSString).lastPathComponent == "node_modules")
}

/// Build/cache dirs (`.build`, `target`, `Pods`, …) are huge and never hold a project's own
/// deps; the walk must not descend into them, so a node_modules buried inside one is not emitted.
@Test func nodeModulesPrunesBuildAndCacheDirs() async {
    let tmp = TempDir(); defer { tmp.cleanup() }
    tmp.makeDir("proj/node_modules")
    tmp.makeDir("proj/.build/nested/node_modules") // inside a pruned dir → must NOT be emitted
    let module = NodeModulesModule(roots: [tmp.url.path], reclaimer: emptyLayerReclaimer(RecordingDeleter()))
    let items = await module.scan()
    #expect(items.count == 1)
    #expect(items.first!.path!.hasSuffix("/proj/node_modules"))
}

/// `maxDepth` is a safety net: a target dir nested deeper than the bound is not emitted.
@Test func nodeModulesRespectsMaxDepth() async {
    let tmp = TempDir(); defer { tmp.cleanup() }
    tmp.makeDir("proj/node_modules")       // parent "proj" at depth 1 — within bound
    tmp.makeDir("proj/a/b/c/node_modules") // parent "c" at depth 4 — beyond maxDepth=3
    let module = NodeModulesModule(
        roots: [tmp.url.path],
        reclaimer: emptyLayerReclaimer(RecordingDeleter()),
        maxDepth: 3
    )
    let parents = await module.scan()
        .map { (($0.path! as NSString).deletingLastPathComponent as NSString).lastPathComponent }
    #expect(parents.contains("proj"))
    #expect(!parents.contains("c"))
}

// M2 regression — the pyiri lesson applied to node_modules: an ACTIVE project (recent
// source) must be auto-protected at reclaim time by ParentProjectActivitySignal.
@Test func nodeModulesActiveProjectIsProtectedEndToEnd() async {
    let tmp = TempDir(); defer { tmp.cleanup() }
    tmp.makeDir("proj/node_modules")
    tmp.writeFile("proj/src/main.ts", "console.log(1)")  // recent source ⇒ active
    let deleter = RecordingDeleter(bytesPerCall: 8192)
    let projectLayer = DefaultSafetyLayer.make()  // includes ParentProjectActivitySignal + RecentUse
    let reclaimer = Reclaimer(safety: projectLayer, deleter: deleter)
    let module = NodeModulesModule(roots: [tmp.url.path], reclaimer: reclaimer)
    let outcomes = await module.reclaim(await module.scan(), dryRun: false)
    #expect(outcomes.first?.status == .skippedProtected)
    #expect(await deleter.callCount == 0)
}
