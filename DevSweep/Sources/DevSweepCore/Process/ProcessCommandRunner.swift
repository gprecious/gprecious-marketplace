import Foundation

/// Real CommandRunner backed by Foundation.Process. Thin on purpose — parsing logic
/// lives in the callers (signals, modules), not here.
public struct ProcessCommandRunner: CommandRunner {
    public init() {}

    public func runResult(_ executable: String, _ args: [String]) async throws -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = args
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()  // discard stderr

        try process.run()
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let text = String(data: data, encoding: .utf8) ?? ""
        return CommandResult(stdout: text, exitCode: process.terminationStatus)
    }
}
