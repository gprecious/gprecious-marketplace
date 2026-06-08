import Foundation
import Testing
@testable import DevSweepCore

@Test func parentProjectActiveWhenSiblingSourceIsRecent() async {
    let temp = TempDir()
    defer { temp.cleanup() }
    // project/ contains node_modules/ (candidate) and a recently edited src file.
    let nodeModules = temp.makeDir("project/node_modules")
    let src = temp.writeFile("project/src/index.ts", "console.log(1)")
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    try? FileManager.default.setAttributes([.modificationDate: now], ofItemAtPath: src)

    let signal = ParentProjectActivitySignal(thresholdDays: 30, now: { now })
    #expect(await signal.isActive(path: nodeModules) == true)
    #expect(signal.name == "parent-project")
}

@Test func parentProjectInactiveWhenAllSourceIsStale() async {
    let temp = TempDir()
    defer { temp.cleanup() }
    let nodeModules = temp.makeDir("project/node_modules")
    let src = temp.writeFile("project/src/index.ts", "console.log(1)")
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let old = now.addingTimeInterval(-90 * 86_400)
    try? FileManager.default.setAttributes([.modificationDate: old], ofItemAtPath: src)
    // also age the src dir itself
    try? FileManager.default.setAttributes([.modificationDate: old],
                                           ofItemAtPath: (src as NSString).deletingLastPathComponent)

    let signal = ParentProjectActivitySignal(thresholdDays: 30, now: { now })
    #expect(await signal.isActive(path: nodeModules) == false)
}

@Test func parentProjectIgnoresExcludedDirs() async {
    let temp = TempDir()
    defer { temp.cleanup() }
    let nodeModules = temp.makeDir("project/node_modules")
    // The only "recent" file lives inside an excluded dir (.git) -> must be ignored.
    let gitFile = temp.writeFile("project/.git/COMMIT_EDITMSG", "wip")
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    try? FileManager.default.setAttributes([.modificationDate: now], ofItemAtPath: gitFile)

    let signal = ParentProjectActivitySignal(thresholdDays: 30, now: { now })
    #expect(await signal.isActive(path: nodeModules) == false)
}
