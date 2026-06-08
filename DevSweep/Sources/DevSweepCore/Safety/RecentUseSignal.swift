import Foundation

/// Signal: was `path` modified within `thresholdDays`? Recent modification means the
/// resource is likely still in use. The clock is injected for deterministic tests.
public struct RecentUseSignal: ActivitySignal, @unchecked Sendable {
    public let name = "recent-use"
    private let thresholdDays: Int
    private let now: @Sendable () -> Date
    private let fileManager: FileManager

    public init(
        thresholdDays: Int = 30,
        now: @escaping @Sendable () -> Date = Date.init,
        fileManager: FileManager = .default
    ) {
        self.thresholdDays = thresholdDays
        self.now = now
        self.fileManager = fileManager
    }

    public func isActive(path: String) async -> Bool {
        guard let attrs = try? fileManager.attributesOfItem(atPath: path),
              let mtime = attrs[.modificationDate] as? Date else {
            return false
        }
        let cutoff = now().addingTimeInterval(-Double(thresholdDays) * 86_400)
        return mtime >= cutoff
    }
}
