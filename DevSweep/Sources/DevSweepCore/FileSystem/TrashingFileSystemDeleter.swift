import Foundation

/// The production `FileSystemDeleter`. It measures the target's size *before* removing it — so
/// the reclaimed-byte total is reported even though the bits are gone — then deletes it: to the
/// user's Trash when `toTrash`, otherwise a permanent `removeItem`. Size is computed with
/// `DirectorySizer`, so directory totals match exactly what `scan()` reported (symlinks not
/// followed, unreadable entries counted as zero).
///
/// Real deletion is intentionally isolated behind this single type: the rest of the suite uses a
/// recording double, and only this type's own tests ever remove real files — strictly inside a
/// `$TMPDIR` fixture.
public struct TrashingFileSystemDeleter: FileSystemDeleter {
    public init() {}

    public func delete(path: String, toTrash: Bool) async throws -> Int64 {
        let bytes = DirectorySizer().size(of: path)
        let url = URL(fileURLWithPath: path)
        if toTrash {
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
        } else {
            try FileManager.default.removeItem(at: url)
        }
        return bytes
    }
}
