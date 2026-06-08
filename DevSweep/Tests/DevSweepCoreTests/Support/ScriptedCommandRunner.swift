import Foundation
import Testing
@testable import DevSweepCore

/// Test double keyed by the FULL command (`exe arg1 arg2 ...`). Each key holds a FIFO
/// queue of responses, so the same command can return different output across calls
/// (docker before/after measurement). Unscripted commands return empty + exit 0.
actor ScriptedCommandRunner: CommandRunner {
    struct Response: Sendable { let stdout: String; let exitCode: Int32
        init(stdout: String = "", exitCode: Int32 = 0) { self.stdout = stdout; self.exitCode = exitCode }
    }

    private var queues: [String: [Response]]
    private(set) var calls: [String] = []

    init(_ scripted: [String: [Response]]) { self.queues = scripted }

    private func key(_ exe: String, _ args: [String]) -> String {
        ([exe] + args).joined(separator: " ")
    }

    func runResult(_ executable: String, _ args: [String]) async throws -> CommandResult {
        let k = key(executable, args)
        calls.append(k)
        if var queue = queues[k], !queue.isEmpty {
            let response = queue.removeFirst()
            queues[k] = queue
            return CommandResult(stdout: response.stdout, exitCode: response.exitCode)
        }
        return CommandResult(stdout: "", exitCode: 0)
    }

    var callCount: Int { calls.count }
}

@Test func scriptedRunnerReturnsFifoPerCommand() async throws {
    let runner = ScriptedCommandRunner([
        "/bin/x a": [.init(stdout: "first", exitCode: 0), .init(stdout: "second", exitCode: 0)]
    ])
    let r1 = try await runner.runResult("/bin/x", ["a"])
    let r2 = try await runner.runResult("/bin/x", ["a"])
    #expect(r1.stdout == "first")
    #expect(r2.stdout == "second")
    #expect(await runner.callCount == 2)
}

@Test func scriptedRunnerUnscriptedIsEmptySuccess() async throws {
    let runner = ScriptedCommandRunner([:])
    let r = try await runner.runResult("/bin/missing", ["z"])
    #expect(r.stdout.isEmpty)
    #expect(r.exitCode == 0)
}

@Test func scriptedRunnerCarriesExitCode() async throws {
    let runner = ScriptedCommandRunner(["/bin/fail q": [.init(exitCode: 1)]])
    let r = try await runner.runResult("/bin/fail", ["q"])
    #expect(r.exitCode == 1)
}
