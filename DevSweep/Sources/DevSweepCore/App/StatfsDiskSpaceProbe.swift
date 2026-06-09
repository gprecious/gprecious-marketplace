import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// `DiskSpaceProbe` backed by a real `statvfs(2)` call. POSIX `statvfs` behaves
/// identically on Darwin and Glibc, so the same code reads the volume that
/// contains `path`. Free space counts blocks available to unprivileged users
/// (`f_bavail`) — what the user can actually reclaim — sized by the fundamental
/// block size (`f_frsize`). A failed call reports zeros rather than trapping.
public struct StatfsDiskSpaceProbe: DiskSpaceProbe {
    public let path: String

    public init(path: String = "/") {
        self.path = path
    }

    public func snapshot() -> (freeBytes: Int64, totalBytes: Int64) {
        var info = statvfs()
        guard statvfs(path, &info) == 0 else {
            return (freeBytes: 0, totalBytes: 0)
        }
        let unit = Int64(info.f_frsize)
        let free = Int64(info.f_bavail) * unit
        let total = Int64(info.f_blocks) * unit
        return (freeBytes: free, totalBytes: total)
    }
}
