import Foundation

/// Creates a unique temp directory for fixtures and removes it on `cleanup()`.
/// This is the ONLY place tests touch the real filesystem, and only under $TMPDIR.
struct TempDir {
    let url: URL

    init() {
        url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("devsweep-tests-" + UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    /// Write `contents` to a file at relative `name`, creating intermediate dirs.
    @discardableResult
    func writeFile(_ name: String, _ contents: String) -> String {
        let fileURL = url.appendingPathComponent(name)
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        try? contents.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL.path
    }

    /// Create an empty directory at relative `name` and return its absolute path.
    @discardableResult
    func makeDir(_ name: String) -> String {
        let dirURL = url.appendingPathComponent(name, isDirectory: true)
        try? FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
        return dirURL.path
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: url)
    }
}
