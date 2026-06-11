import Foundation

/// One entry from `git worktree list --porcelain`.
public struct WorktreeEntry: Sendable, Equatable {
    public let path: String
    public let head: String
    public let branch: String?   // short name; nil when detached
    public let isMain: Bool       // first entry in porcelain order
    public let isLocked: Bool
    public let isPrunable: Bool
    public let isBare: Bool

    public init(path: String, head: String, branch: String?, isMain: Bool,
                isLocked: Bool, isPrunable: Bool, isBare: Bool) {
        self.path = path; self.head = head; self.branch = branch; self.isMain = isMain
        self.isLocked = isLocked; self.isPrunable = isPrunable; self.isBare = isBare
    }
}

/// Parses `git worktree list --porcelain`. Blocks are separated by a blank line; the first
/// block is always the main working tree.
public enum WorktreeListParser {
    public static func parse(_ porcelain: String) -> [WorktreeEntry] {
        var entries: [WorktreeEntry] = []
        for block in porcelain.components(separatedBy: "\n\n") {
            let lines = block.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
            guard let wtLine = lines.first(where: { $0.hasPrefix("worktree ") }) else { continue }
            let path = String(wtLine.dropFirst("worktree ".count))
            var head = ""
            var branch: String? = nil
            var isLocked = false, isPrunable = false, isBare = false
            for line in lines {
                if line.hasPrefix("HEAD ") {
                    head = String(line.dropFirst("HEAD ".count))
                } else if line.hasPrefix("branch ") {
                    let ref = String(line.dropFirst("branch ".count))
                    branch = ref.hasPrefix("refs/heads/") ? String(ref.dropFirst("refs/heads/".count)) : ref
                } else if line == "detached" {
                    branch = nil
                } else if line == "bare" {
                    isBare = true
                } else if line == "locked" || line.hasPrefix("locked ") {
                    isLocked = true
                } else if line == "prunable" || line.hasPrefix("prunable ") {
                    isPrunable = true
                }
            }
            entries.append(WorktreeEntry(path: path, head: head, branch: branch,
                                         isMain: entries.isEmpty, isLocked: isLocked,
                                         isPrunable: isPrunable, isBare: isBare))
        }
        return entries
    }
}
