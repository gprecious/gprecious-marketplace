import Foundation

/// Computes the total byte size under a path. Manual recursion (mirrors
/// ParentProjectActivitySignal) so behavior is deterministic: symlinks are NOT
/// followed (attributesOfItem uses lstat), unreadable entries are skipped.
public struct DirectorySizer: @unchecked Sendable {
    public static let defaultScanDescendantLimit = 0

    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    /// Total bytes of regular files under `path`. `0` if the path is missing/unreadable.
    /// When `maxDescendantEntries` is set, the walk stops after visiting that many child
    /// filesystem entries under `path`; this gives scan-time callers a bounded estimate.
    public func size(of path: String, maxDescendantEntries: Int? = nil) -> Int64 {
        var total: Int64 = 0
        var remainingDescendantEntries = maxDescendantEntries.map { max(0, $0) }
        accumulate(path, into: &total, remainingDescendantEntries: &remainingDescendantEntries, countsAgainstBudget: false)
        return total
    }

    private func accumulate(
        _ path: String,
        into total: inout Int64,
        remainingDescendantEntries: inout Int?,
        countsAgainstBudget: Bool = true
    ) {
        if countsAgainstBudget, let remaining = remainingDescendantEntries {
            guard remaining > 0 else { return }
            remainingDescendantEntries = remaining - 1
        }
        guard let attrs = try? fileManager.attributesOfItem(atPath: path) else { return }
        let type = attrs[.type] as? FileAttributeType
        switch type {
        case .typeSymbolicLink:
            return  // never follow links
        case .typeDirectory:
            if let remaining = remainingDescendantEntries, remaining <= 0 { return }
            guard let entries = try? fileManager.contentsOfDirectory(atPath: path) else { return }
            for entry in entries {
                if let remaining = remainingDescendantEntries, remaining <= 0 { break }
                accumulate(
                    (path as NSString).appendingPathComponent(entry),
                    into: &total,
                    remainingDescendantEntries: &remainingDescendantEntries
                )
            }
        case .typeRegular:
            if let size = attrs[.size] as? Int64 { total += size }
        default:
            return
        }
    }
}
