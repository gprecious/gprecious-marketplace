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

@Test func nodeModulesReclaimDeletesWhenLayerHasNoSignals() async {
    let tmp = TempDir(); defer { tmp.cleanup() }
    tmp.makeDir("proj/node_modules")
    let deleter = RecordingDeleter(bytesPerCall: 8192)
    let module = NodeModulesModule(roots: [tmp.url.path], reclaimer: emptyLayerReclaimer(deleter))
    let outcomes = await module.reclaim(await module.scan(), dryRun: false)
    #expect(outcomes.first?.status == .deleted(bytes: 8192))
    #expect(await deleter.callCount == 1)
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
