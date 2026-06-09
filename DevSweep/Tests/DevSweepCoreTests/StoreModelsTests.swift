import Foundation
import Testing
@testable import DevSweepCore

@Test func scanRecordTotalIsSumOfPerModule() {
    let record = ScanRecord(
        id: "scan-1",
        timestamp: Date(timeIntervalSince1970: 1_700_000_000),
        perModule: ["docker": 3_000_000_000, "package-cache": 9_300_000_000, "node-modules": 1_000]
    )
    #expect(record.totalBytes == 12_300_001_000)
    #expect(record.totalBytes == record.perModule.values.reduce(0, +))
}

@Test func scanRecordEmptyPerModuleHasZeroTotal() {
    let record = ScanRecord(id: "scan-0", timestamp: Date(timeIntervalSince1970: 0), perModule: [:])
    #expect(record.totalBytes == 0)
}

@Test func scanRecordEquatable() {
    let ts = Date(timeIntervalSince1970: 1_700_000_000)
    let a = ScanRecord(id: "s1", timestamp: ts, perModule: ["docker": 10])
    let b = ScanRecord(id: "s1", timestamp: ts, perModule: ["docker": 10])
    let c = ScanRecord(id: "s2", timestamp: ts, perModule: ["docker": 10])
    #expect(a == b)
    #expect(a != c)
}

@Test func auditRecordHoldsFieldsAndIsEquatable() {
    let ts = Date(timeIntervalSince1970: 1_700_000_000)
    let a = AuditRecord(timestamp: ts, itemId: "docker:build-cache", moduleId: "docker",
                        method: "cliCommand(docker builder prune -f)", bytesReclaimed: 2_048, status: "deleted")
    let b = AuditRecord(timestamp: ts, itemId: "docker:build-cache", moduleId: "docker",
                        method: "cliCommand(docker builder prune -f)", bytesReclaimed: 2_048, status: "deleted")
    #expect(a == b)
    #expect(a.moduleId == "docker")
    #expect(a.status == "deleted")

    let nilModule = AuditRecord(timestamp: ts, itemId: "/Users/x/.npm", moduleId: nil,
                                method: "deletePath(trash:false)", bytesReclaimed: 0, status: "dryRun")
    #expect(nilModule.moduleId == nil)
    #expect(a != nilModule)
}
