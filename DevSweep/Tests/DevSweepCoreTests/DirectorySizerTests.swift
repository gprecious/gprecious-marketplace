import Foundation
import Testing
@testable import DevSweepCore

@Test func directorySizerSumsKnownFileSizes() {
    let tmp = TempDir(); defer { tmp.cleanup() }
    tmp.writeFile("a.txt", String(repeating: "x", count: 100))   // 100 bytes
    tmp.writeFile("sub/b.txt", String(repeating: "y", count: 50)) // 50 bytes
    let sizer = DirectorySizer()
    #expect(sizer.size(of: tmp.url.path) == 150)
}

@Test func directorySizerDoesNotFollowSymlinks() throws {
    let tmp = TempDir(); defer { tmp.cleanup() }
    let target = tmp.writeFile("real.txt", String(repeating: "z", count: 200))
    let linkPath = (tmp.url.path as NSString).appendingPathComponent("link.txt")
    try FileManager.default.createSymbolicLink(atPath: linkPath, withDestinationPath: target)
    let sizer = DirectorySizer()
    // Only real.txt (200) counts; the symlink is skipped, not followed.
    #expect(sizer.size(of: tmp.url.path) == 200)
}

@Test func directorySizerReturnsZeroForMissingPath() {
    let sizer = DirectorySizer()
    #expect(sizer.size(of: "/nonexistent/devsweep/path") == 0)
}

@Test func directorySizerStopsAtDescendantEntryBudget() {
    let tmp = TempDir(); defer { tmp.cleanup() }
    tmp.writeFile("a.txt", String(repeating: "a", count: 10))
    tmp.writeFile("b.txt", String(repeating: "b", count: 10))
    tmp.writeFile("c.txt", String(repeating: "c", count: 10))

    let sizer = DirectorySizer()
    #expect(sizer.size(of: tmp.url.path, maxDescendantEntries: 2) == 20)
}

@Test func defaultScanDescendantBudgetIsSmallEnoughForMenuBarLaunch() {
    #expect(DirectorySizer.defaultScanDescendantLimit > 0)
    #expect(DirectorySizer.defaultScanDescendantLimit <= 256)
}

@Test func defaultScanDescendantBudgetReportsNonZeroForNonEmptyDirectory() {
    let tmp = TempDir(); defer { tmp.cleanup() }
    tmp.writeFile("payload.txt", String(repeating: "x", count: 10))

    let sizer = DirectorySizer()
    #expect(sizer.size(of: tmp.url.path, maxDescendantEntries: DirectorySizer.defaultScanDescendantLimit) > 0)
}

@Test func defaultScanDescendantBudgetReportsZeroForEmptyDirectory() {
    let tmp = TempDir(); defer { tmp.cleanup() }

    let sizer = DirectorySizer()
    #expect(sizer.size(of: tmp.url.path, maxDescendantEntries: DirectorySizer.defaultScanDescendantLimit) == 0)
}
