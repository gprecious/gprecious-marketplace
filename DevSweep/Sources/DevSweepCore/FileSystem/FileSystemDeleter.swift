/// Abstraction over real deletion so destructive operations are isolated behind an
/// interface. Tests inject a recording double; nothing in the test suite ever removes files.
public protocol FileSystemDeleter: Sendable {
    /// Delete `path` (to Trash if `toTrash`). Returns the number of bytes reclaimed.
    func delete(path: String, toTrash: Bool) async throws -> Int64
}
