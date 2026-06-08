import Foundation
import Testing
@testable import DevSweepCore

/// Test double: canned stdout + optional exit code keyed by executable. Records nothing.
/// `exitCodes` defaults to empty so M1 call sites `MockCommandRunner(outputs:)` still compile.
struct MockCommandRunner: CommandRunner {
    let outputs: [String: String]
    var exitCodes: [String: Int32] = [:]

    func runResult(_ executable: String, _ args: [String]) async throws -> CommandResult {
        CommandResult(stdout: outputs[executable] ?? "", exitCode: exitCodes[executable] ?? 0)
    }
}

@Test func mockCommandRunnerReturnsCannedOutput() async throws {
    let runner = MockCommandRunner(outputs: ["/usr/bin/crontab": "0 3 * * * echo hi\n"])
    let out = try await runner.run("/usr/bin/crontab", ["-l"])
    #expect(out.contains("echo hi"))
}

@Test func mockCommandRunnerReturnsCannedExitCode() async throws {
    let runner = MockCommandRunner(outputs: ["/bin/x": ""], exitCodes: ["/bin/x": 7])
    let result = try await runner.runResult("/bin/x", [])
    #expect(result.exitCode == 7)
}

@Test func processCommandRunnerCapturesEcho() async throws {
    let runner = ProcessCommandRunner()
    let out = try await runner.run("/bin/echo", ["devsweep-ok"])
    #expect(out.trimmingCharacters(in: .whitespacesAndNewlines) == "devsweep-ok")
}

@Test func processCommandRunnerCapturesExitCode() async throws {
    let runner = ProcessCommandRunner()
    let result = try await runner.runResult("/bin/sh", ["-c", "exit 3"])
    #expect(result.exitCode == 3)
    #expect(result.stdout.isEmpty)
}

@Test func runDefaultExtensionStillReturnsStdoutOnly() async throws {
    let runner = ProcessCommandRunner()
    let out = try await runner.run("/bin/echo", ["devsweep-ext"])
    #expect(out.trimmingCharacters(in: .whitespacesAndNewlines) == "devsweep-ext")
}
