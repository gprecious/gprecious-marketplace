import Testing
@testable import DevSweepCore

/// Test double for ActivitySignal: reports active only for paths in `activePaths`.
struct MockActivitySignal: ActivitySignal {
    let name: String
    let activePaths: Set<String>

    func isActive(path: String) async -> Bool {
        activePaths.contains(path)
    }
}

@Test func mockActivitySignalReportsConfiguredPaths() async {
    let signal = MockActivitySignal(name: "test", activePaths: ["/a"])
    #expect(await signal.isActive(path: "/a") == true)
    #expect(await signal.isActive(path: "/b") == false)
}
