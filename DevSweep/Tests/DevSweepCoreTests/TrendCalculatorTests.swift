import Foundation
import Testing
@testable import DevSweepCore

private func rec(_ id: String, _ epoch: TimeInterval, _ per: [String: Int64]) -> ScanRecord {
    ScanRecord(id: id, timestamp: Date(timeIntervalSince1970: epoch), perModule: per)
}

private let calc = TrendCalculator()

@Test func currentTotalIsLatestScanTotal() {
    let s1 = rec("s1", 100, ["docker": 5, "npm": 5])
    let s2 = rec("s2", 200, ["docker": 10, "npm": 10])
    let s3 = rec("s3", 300, ["docker": 30, "npm": 5, "uv": 12])
    #expect(calc.currentTotal([s1, s2, s3]) == 47)
    #expect(calc.currentTotal([s3, s1, s2]) == 47)   // order-independent
    #expect(calc.currentTotal([]) == 0)
}

@Test func deltaSinceComparesLatestToBaseline() {
    let s1 = rec("s1", 100, ["docker": 5, "npm": 5])    // 10
    let s2 = rec("s2", 200, ["docker": 10, "npm": 10])  // 20
    let s3 = rec("s3", 300, ["docker": 30, "npm": 5, "uv": 12]) // 47
    let scans = [s1, s2, s3]
    // baseline = most recent scan at/before `since`
    #expect(calc.delta(scans, since: Date(timeIntervalSince1970: 250)) == 27)  // 47 - 20
    // since before all scans → baseline 0
    #expect(calc.delta(scans, since: Date(timeIntervalSince1970: 50)) == 47)
}

@Test func topModulesSortedByBytesDescending() {
    let s = rec("s", 300, ["docker": 30, "npm": 5, "uv": 12])
    let top2 = calc.topModules(s, limit: 2)
    #expect(top2.map(\.module) == ["docker", "uv"])
    #expect(top2.map(\.bytes) == [30, 12])
    let all = calc.topModules(s, limit: 10)
    #expect(all.map(\.module) == ["docker", "uv", "npm"])
}

@Test func isGrowingReflectsRecentTwoScans() {
    let a = rec("a", 100, ["docker": 50])
    let b = rec("b", 200, ["docker": 20])
    let c = rec("c", 300, ["docker": 90])
    #expect(calc.isGrowing([a, b, c]) == true)    // recent two: c(90) > b(20)
    #expect(calc.isGrowing([a, b]) == false)      // b(20) < a(50)
    #expect(calc.isGrowing([a]) == false)         // single scan
    #expect(calc.isGrowing([]) == false)          // empty
    let eq1 = rec("e1", 100, ["docker": 20])
    let eq2 = rec("e2", 200, ["docker": 20])
    #expect(calc.isGrowing([eq1, eq2]) == false)  // equal is not growing
}
