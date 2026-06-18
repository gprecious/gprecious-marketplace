import Foundation

/// Real CommandRunner backed by Foundation.Process. Thin on purpose — parsing logic
/// lives in the callers (signals, modules), not here.
public struct ProcessCommandRunner: CommandRunner {
    private let environment: [String: String]?

    public init(environment: [String: String]? = nil) {
        self.environment = environment
    }

    public func runResult(_ executable: String, _ args: [String]) async throws -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = args
        process.environment = Self.environmentWithDefaultPath(environment ?? ProcessInfo.processInfo.environment)
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()  // discard stderr

        try process.run()
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let text = String(data: data, encoding: .utf8) ?? ""
        return CommandResult(stdout: text, exitCode: process.terminationStatus)
    }

    static func environmentWithDefaultPath(_ base: [String: String]) -> [String: String] {
        var environment = base
        let defaults = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin", "/usr/sbin", "/sbin"]
        let existing = (base["PATH"] ?? "")
            .split(separator: ":")
            .map(String.init)
        let merged = defaults + existing.filter { !defaults.contains($0) }
        environment["PATH"] = merged.joined(separator: ":")
        return environment
    }
}
