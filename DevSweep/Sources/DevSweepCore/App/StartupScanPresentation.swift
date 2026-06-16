import Foundation

/// Restores the last persisted scan into the initial UI state before a fresh scan can run.
/// This prevents "0 bytes" from replacing a known previous result when Full Disk Access is missing.
public struct StartupScanPresentation: Sendable {
    public struct TopModule: Sendable, Equatable {
        public let module: String
        public let name: String
        public let bytes: Int64

        public init(module: String, name: String, bytes: Int64) {
            self.module = module
            self.name = name
            self.bytes = bytes
        }
    }

    public struct Snapshot: Sendable, Equatable {
        public let reclaimableBytes: Int64
        public let topModules: [TopModule]
        public let lastScanDate: Date

        public init(reclaimableBytes: Int64, topModules: [TopModule], lastScanDate: Date) {
            self.reclaimableBytes = reclaimableBytes
            self.topModules = topModules
            self.lastScanDate = lastScanDate
        }
    }

    private let trend = TrendCalculator()

    public init() {}

    public func restore(
        from latestScan: ScanRecord?,
        moduleNames: [String: String],
        limit: Int = 5
    ) -> Snapshot? {
        guard let latestScan else { return nil }
        let topModules = trend.topModules(latestScan, limit: limit)
            .map {
                TopModule(
                    module: $0.module,
                    name: moduleNames[$0.module] ?? $0.module,
                    bytes: $0.bytes
                )
            }
        return Snapshot(
            reclaimableBytes: latestScan.totalBytes,
            topModules: topModules,
            lastScanDate: latestScan.timestamp
        )
    }
}

public struct ScanPermissionPolicy: Sendable {
    public init() {}

    public func canRunScan(hasFullDiskAccess: Bool) -> Bool {
        hasFullDiskAccess
    }
}
