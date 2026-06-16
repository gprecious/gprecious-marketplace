import Foundation
import Testing
@testable import DevSweepCore

@Test func startupScanPresentationRestoresLatestScanForInitialDisplay() {
    let timestamp = Date(timeIntervalSince1970: 123)
    let record = ScanRecord(
        id: "latest",
        timestamp: timestamp,
        perModule: [
            "node-modules": 50,
            "package-cache": 20,
        ]
    )

    let snapshot = StartupScanPresentation().restore(
        from: record,
        moduleNames: ["node-modules": "Node Modules"],
        limit: 5
    )

    #expect(snapshot?.reclaimableBytes == 70)
    #expect(snapshot?.lastScanDate == timestamp)
    #expect(snapshot?.topModules == [
        StartupScanPresentation.TopModule(module: "node-modules", name: "Node Modules", bytes: 50),
        StartupScanPresentation.TopModule(module: "package-cache", name: "package-cache", bytes: 20),
    ])
}

@Test func startupScanPresentationReturnsNilWithoutStoredScan() {
    #expect(StartupScanPresentation().restore(from: nil, moduleNames: [:]) == nil)
}

@Test func scanPermissionPolicyRequiresFullDiskAccess() {
    let policy = ScanPermissionPolicy()

    #expect(policy.canRunScan(hasFullDiskAccess: true))
    #expect(policy.canRunScan(hasFullDiskAccess: false) == false)
}
