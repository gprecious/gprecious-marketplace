import Foundation

/// Signal: does any LaunchAgent plist reference `path`? A KeepAlive agent pointing into
/// the path means deleting the dir would break a managed service (the pyiri case).
public struct LaunchdReferenceSignal: ActivitySignal, @unchecked Sendable {
    public let name = "launchd"
    private let launchAgentsDir: String
    private let fileManager: FileManager

    public init(
        launchAgentsDir: String = (("~/Library/LaunchAgents") as NSString).expandingTildeInPath,
        fileManager: FileManager = .default
    ) {
        self.launchAgentsDir = launchAgentsDir
        self.fileManager = fileManager
    }

    public func isActive(path: String) async -> Bool {
        guard let entries = try? fileManager.contentsOfDirectory(atPath: launchAgentsDir) else {
            return false
        }
        for entry in entries where entry.hasSuffix(".plist") {
            let full = (launchAgentsDir as NSString).appendingPathComponent(entry)
            if let contents = try? String(contentsOfFile: full, encoding: .utf8),
               contents.contains(path) {
                return true
            }
        }
        return false
    }
}
