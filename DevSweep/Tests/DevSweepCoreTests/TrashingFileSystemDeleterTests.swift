import Foundation
import Testing
@testable import DevSweepCore

/// `TrashingFileSystemDeleter` is the ONLY production code that removes real files. Every test
/// here operates strictly inside a `$TMPDIR` fixture (`TempDir`) and deletes only what it
/// created — never anything outside the temp sandbox.

@Test func trashingDeleterRemovesDirectoryAndReturnsMeasuredBytes() async throws {
    let tmp = TempDir(); defer { tmp.cleanup() }
    let dir = tmp.makeDir("payload")
    tmp.writeFile("payload/a.txt", String(repeating: "x", count: 100)) // 100 bytes
    tmp.writeFile("payload/sub/b.txt", String(repeating: "y", count: 50)) // 50 bytes

    let deleter = TrashingFileSystemDeleter()
    let bytes = try await deleter.delete(path: dir, toTrash: false)

    #expect(bytes == 150)
    #expect(FileManager.default.fileExists(atPath: dir) == false)
}

@Test func trashingDeleterRemovesSingleFileAndReturnsItsSize() async throws {
    let tmp = TempDir(); defer { tmp.cleanup() }
    let file = tmp.writeFile("solo.bin", String(repeating: "z", count: 321))

    let deleter = TrashingFileSystemDeleter()
    let bytes = try await deleter.delete(path: file, toTrash: false)

    #expect(bytes == 321)
    #expect(FileManager.default.fileExists(atPath: file) == false)
}

@Test func trashingDeleterThrowsOnMissingPath() async {
    let deleter = TrashingFileSystemDeleter()
    var threw = false
    do {
        _ = try await deleter.delete(
            path: "/nonexistent/devsweep/\(UUID().uuidString)",
            toTrash: false
        )
    } catch {
        threw = true
    }
    #expect(threw)
}

@Test func trashingDeleterMovesSourceToTrashAndReportsMeasuredBytes() async throws {
    let tmp = TempDir(); defer { tmp.cleanup() }
    let file = tmp.writeFile("trashme-\(UUID().uuidString).txt", String(repeating: "t", count: 234))
    let basename = (file as NSString).lastPathComponent

    let deleter = TrashingFileSystemDeleter()
    let bytes = try await deleter.delete(path: file, toTrash: true)

    #expect(bytes == 234)
    #expect(FileManager.default.fileExists(atPath: file) == false)

    // Best-effort: don't leave the fixture lingering in the user's Trash.
    let trashed = (NSHomeDirectory() as NSString).appendingPathComponent(".Trash/\(basename)")
    try? FileManager.default.removeItem(atPath: trashed)
}
