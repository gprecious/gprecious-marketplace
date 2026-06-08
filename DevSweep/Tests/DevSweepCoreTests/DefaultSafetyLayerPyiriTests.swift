import Foundation
import Testing
@testable import DevSweepCore

/// Capstone integration: compose the REAL signals (with mocked external commands and a
/// fixture LaunchAgents dir) and reproduce the full pyiri scenario end-to-end. The 4.7GB
/// candidate must be downgraded to .protected by process + launchd + crontab together.
@Test func defaultSafetyLayerProtectsPyiriEndToEnd() async {
    let temp = TempDir()
    defer { temp.cleanup() }
    let pyiri = temp.makeDir(".openclaw-pyiri")

    let agentsDir = temp.makeDir("LaunchAgents")
    temp.writeFile("LaunchAgents/com.openclaw.pyiri.plist",
                   "<plist><dict><key>OPENCLAW_HOME</key><string>\(pyiri)</string></dict></plist>")

    let commandRunner = MockCommandRunner(outputs: [
        "/usr/sbin/lsof": "openclaw 3788 x cwd DIR \(pyiri)\n",
        "/usr/bin/crontab": "0 3 * * * find \(pyiri)/logs -name '*.log' -mtime +7 -delete\n"
    ])

    let layer = DefaultSafetyLayer.make(
        commandRunner: commandRunner,
        launchAgentsDir: agentsDir,
        registry: ProtectedRegistry(userExcluded: [], systemProtected: [])
    )

    let candidate = CleanupItem(
        id: pyiri, path: pyiri, sizeBytes: 4_700_000_000, lastUsed: nil,
        safety: .reviewNeeded, reclaimMethod: .deletePath(toTrash: false)
    )
    let eval = await layer.evaluate(candidate)

    #expect(eval.item.safety == .protected)
    #expect(eval.downgradedBy.contains("process"))
    #expect(eval.downgradedBy.contains("launchd"))
    #expect(eval.downgradedBy.contains("crontab"))
}

/// A genuinely dead directory (no process, no launchd, no crontab, stale mtime, no recent
/// parent source) is NOT downgraded — it stays reclaimable.
@Test func defaultSafetyLayerLeavesDeadCacheReclaimable() async {
    let temp = TempDir()
    defer { temp.cleanup() }
    let deadCache = temp.makeDir("project/node_modules")
    // age the whole project so recent-use + parent-project are inactive
    let old = Date(timeIntervalSince1970: 1_700_000_000).addingTimeInterval(-120 * 86_400)
    try? FileManager.default.setAttributes([.modificationDate: old], ofItemAtPath: deadCache)

    let agentsDir = temp.makeDir("LaunchAgents")  // empty
    let commandRunner = MockCommandRunner(outputs: [
        "/usr/sbin/lsof": "",
        "/usr/bin/crontab": ""
    ])

    let layer = DefaultSafetyLayer.make(
        commandRunner: commandRunner,
        launchAgentsDir: agentsDir,
        registry: ProtectedRegistry(userExcluded: [], systemProtected: []),
        now: { Date(timeIntervalSince1970: 1_700_000_000) }
    )

    let candidate = CleanupItem(
        id: deadCache, path: deadCache, sizeBytes: 800_000_000, lastUsed: nil,
        safety: .reviewNeeded, reclaimMethod: .deletePath(toTrash: false)
    )
    let eval = await layer.evaluate(candidate)

    #expect(eval.item.safety == .reviewNeeded)
    #expect(eval.downgradedBy.isEmpty)
}
