import Foundation
import Testing
@testable import DevSweepCore

private func sized(_ id: String, _ bytes: Int64) -> CleanupItem {
    CleanupItem(id: id, path: nil, sizeBytes: bytes, lastUsed: nil,
                safety: .autoSafe, reclaimMethod: .cliCommand(executable: "x", arguments: []))
}

private func item(_ id: String, _ method: ReclaimMethod) -> CleanupItem {
    CleanupItem(id: id, path: nil, sizeBytes: 0, lastUsed: nil, safety: .autoSafe, reclaimMethod: method)
}

@Test func scanRecordFromGroupedSumsItemSizesPerModule() {
    let ts = Date(timeIntervalSince1970: 1_700_000_000)
    let grouped: [(module: String, items: [CleanupItem])] = [
        ("docker", [sized("docker:build-cache", 3_000_000_000), sized("docker:unused-images", 2_000_000_000)]),
        ("package-cache", [sized("package-cache:pnpm", 9_000_000_000)]),
    ]
    let record = ScanRecord(id: "scan-7", timestamp: ts, from: grouped)

    #expect(record.id == "scan-7")
    #expect(record.timestamp == ts)
    #expect(record.perModule["docker"] == 5_000_000_000)
    #expect(record.perModule["package-cache"] == 9_000_000_000)
    #expect(record.totalBytes == 14_000_000_000)
}

@Test func auditRecordsMapEveryStatusKind() {
    let ts = Date(timeIntervalSince1970: 1_700_000_500)
    let outcomes: [ReclaimOutcome] = [
        ReclaimOutcome(item: item("docker:build-cache",
                                  .cliCommand(executable: "docker", arguments: ["builder", "prune", "-f"])),
                       status: .deleted(bytes: 2_048)),
        ReclaimOutcome(item: item("/Users/x/.gradle/caches", .deletePath(toTrash: false)),
                       status: .dryRun(plannedBytes: 100)),
        ReclaimOutcome(item: item("/Users/x/inuse", .deletePath(toTrash: true)),
                       status: .skippedProtected),
        ReclaimOutcome(item: item("docker:unused-images",
                                  .cliCommand(executable: "docker", arguments: ["image", "prune", "-a", "-f"])),
                       status: .failed(message: "boom")),
    ]

    let records = StoreBuilders.auditRecords(timestamp: ts, from: outcomes)

    #expect(records.count == 4)
    #expect(records.allSatisfy { $0.timestamp == ts })
    #expect(records[0] == AuditRecord(timestamp: ts, itemId: "docker:build-cache", moduleId: "docker",
                                      method: "cliCommand(docker builder prune -f)",
                                      bytesReclaimed: 2_048, status: "deleted"))
    #expect(records[1] == AuditRecord(timestamp: ts, itemId: "/Users/x/.gradle/caches", moduleId: nil,
                                      method: "deletePath(trash:false)",
                                      bytesReclaimed: 100, status: "dryRun"))
    #expect(records[2] == AuditRecord(timestamp: ts, itemId: "/Users/x/inuse", moduleId: nil,
                                      method: "deletePath(trash:true)",
                                      bytesReclaimed: 0, status: "skippedProtected"))
    #expect(records[3] == AuditRecord(timestamp: ts, itemId: "docker:unused-images", moduleId: "docker",
                                      method: "cliCommand(docker image prune -a -f)",
                                      bytesReclaimed: 0, status: "failed"))
}
