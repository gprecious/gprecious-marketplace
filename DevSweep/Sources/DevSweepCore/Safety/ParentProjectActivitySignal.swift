import Foundation

/// Signal: for a candidate like `.../project/node_modules`, is the *parent project*
/// active? Walks the parent dir (skipping excluded subdirs like node_modules/.git/.venv)
/// and returns true on the first source file modified within `thresholdDays`.
public struct ParentProjectActivitySignal: ActivitySignal, @unchecked Sendable {
    public let name = "parent-project"
    private let thresholdDays: Int
    private let now: @Sendable () -> Date
    private let fileManager: FileManager
    private let excludedDirNames: Set<String>

    public init(
        thresholdDays: Int = 30,
        now: @escaping @Sendable () -> Date = Date.init,
        fileManager: FileManager = .default,
        excludedDirNames: Set<String> = ["node_modules", ".git", ".venv", "venv", ".build"]
    ) {
        self.thresholdDays = thresholdDays
        self.now = now
        self.fileManager = fileManager
        self.excludedDirNames = excludedDirNames
    }

    public func isActive(path: String) async -> Bool {
        let parent = (path as NSString).deletingLastPathComponent
        let cutoff = now().addingTimeInterval(-Double(thresholdDays) * 86_400)
        return hasRecentFile(in: parent, cutoff: cutoff)
    }

    private func hasRecentFile(in dir: String, cutoff: Date) -> Bool {
        guard let entries = try? fileManager.contentsOfDirectory(atPath: dir) else { return false }
        for entry in entries {
            let full = (dir as NSString).appendingPathComponent(entry)
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: full, isDirectory: &isDir) else { continue }

            if isDir.boolValue {
                if excludedDirNames.contains(entry) { continue }
                if hasRecentFile(in: full, cutoff: cutoff) { return true }
            } else {
                if let attrs = try? fileManager.attributesOfItem(atPath: full),
                   let mtime = attrs[.modificationDate] as? Date,
                   mtime >= cutoff {
                    return true
                }
            }
        }
        return false
    }
}
