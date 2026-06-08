import Testing
@testable import DevSweepCore

@Test func cleanupItemSafetyIsMutableForDowngrade() {
    var item = CleanupItem(
        id: "npm-cache",
        path: "/Users/x/.npm",
        sizeBytes: 9_300_000_000,
        lastUsed: nil,
        safety: .autoSafe,
        reclaimMethod: .deletePath(toTrash: false)
    )
    item.safety = .protected
    #expect(item.safety == .protected)
}

@Test func reclaimMethodEquatable() {
    #expect(ReclaimMethod.deletePath(toTrash: true) == .deletePath(toTrash: true))
    #expect(ReclaimMethod.deletePath(toTrash: true) != .deletePath(toTrash: false))
    #expect(
        ReclaimMethod.cliCommand(executable: "docker", arguments: ["builder", "prune"])
        == .cliCommand(executable: "docker", arguments: ["builder", "prune"])
    )
}
