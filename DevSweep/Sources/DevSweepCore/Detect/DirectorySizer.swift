import Foundation

/// Computes the total byte size under a path. Manual recursion (mirrors
/// ParentProjectActivitySignal) so behavior is deterministic: symlinks are NOT
/// followed (attributesOfItem uses lstat), unreadable entries are skipped.
public struct DirectorySizer: @unchecked Sendable {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    /// Total bytes of regular files under `path`. `0` if the path is missing/unreadable.
    public func size(of path: String) -> Int64 {
        var total: Int64 = 0
        accumulate(path, into: &total)
        return total
    }

    private func accumulate(_ path: String, into total: inout Int64) {
        guard let attrs = try? fileManager.attributesOfItem(atPath: path) else { return }
        let type = attrs[.type] as? FileAttributeType
        switch type {
        case .typeSymbolicLink:
            return  // never follow links
        case .typeDirectory:
            guard let entries = try? fileManager.contentsOfDirectory(atPath: path) else { return }
            for entry in entries {
                accumulate((path as NSString).appendingPathComponent(entry), into: &total)
            }
        case .typeRegular:
            if let size = attrs[.size] as? Int64 { total += size }
        default:
            return
        }
    }
}
