import Foundation
import Testing
@testable import DevSweepCore

/// `TCCDatabaseProbe`는 `open(O_RDONLY)` 결과만으로 FDA 유무를 판정한다.
/// fail-safe(불변식 4): `fd >= 0`만 granted, 그 외 모든 결과는 denied.
@Suite struct FullDiskAccessProbeTests {
    @Test func readablePathReportsGranted() throws {
        let dir = NSTemporaryDirectory() + "devsweep-fda-\(UUID().uuidString)"
        let file = dir + "/probe.txt"
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: file, contents: Data("x".utf8))
        defer { try? FileManager.default.removeItem(atPath: dir) }

        #expect(TCCDatabaseProbe(path: file).check() == .granted)
    }

    @Test func missingPathFailsSafeToDenied() {
        let bogus = "/nonexistent/\(UUID().uuidString)/TCC.db"
        #expect(TCCDatabaseProbe(path: bogus).check() == .denied)
    }

    @Test func defaultProbeReturnsAValueWithoutCrashing() {
        // 현 머신 권한 상태 의존 → 값 단정 없음, 크래시·행 없이 둘 중 하나 반환만 확인.
        let status = TCCDatabaseProbe().check()
        #expect(status == .granted || status == .denied)
    }
}
