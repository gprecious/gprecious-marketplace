/// Reads the current free/total bytes of the volume the app cares about. Synchronous
/// (a `statvfs`-class syscall is cheap); injected so policies can be tested against
/// deterministic disk state. Real implementation lands in Phase 2 (`StatfsDiskSpaceProbe`).
public protocol DiskSpaceProbe: Sendable {
    func snapshot() -> (freeBytes: Int64, totalBytes: Int64)
}
