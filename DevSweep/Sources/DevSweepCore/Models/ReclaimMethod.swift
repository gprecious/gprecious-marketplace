/// How a candidate is reclaimed.
public enum ReclaimMethod: Sendable, Equatable {
    /// Delete a filesystem path. `toTrash` moves to Trash instead of permanent removal.
    case deletePath(toTrash: Bool)
    /// Invoke a tool's own CLI (state-aware reclaim), e.g. `docker builder prune`.
    case cliCommand(executable: String, arguments: [String])
}
