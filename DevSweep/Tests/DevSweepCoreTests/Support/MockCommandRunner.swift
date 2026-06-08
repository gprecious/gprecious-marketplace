import Foundation
import Testing
@testable import DevSweepCore

/// Test double: returns canned stdout keyed by executable, records invocations.
struct MockCommandRunner: CommandRunner {
    /// Map of executable path → stdout to return.
    let outputs: [String: String]

    func run(_ executable: String, _ args: [String]) async throws -> String {
        outputs[executable] ?? ""
    }
}

@Test func mockCommandRunnerReturnsCannedOutput() async throws {
    let runner = MockCommandRunner(outputs: ["/usr/bin/crontab": "0 3 * * * echo hi\n"])
    let out = try await runner.run("/usr/bin/crontab", ["-l"])
    #expect(out.contains("echo hi"))
}

@Test func processCommandRunnerCapturesEcho() async throws {
    let runner = ProcessCommandRunner()
    let out = try await runner.run("/bin/echo", ["devsweep-ok"])
    #expect(out.trimmingCharacters(in: .whitespacesAndNewlines) == "devsweep-ok")
}
